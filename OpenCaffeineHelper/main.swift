import Foundation
import os.log

// OpenCaffeineHelper runs as root, started by launchd on Open Caffeine's behalf
// (SMAppService.daemon). It can only run `pmset -a disablesleep 1|0` for the signed
// Open Caffeine app, and `pmset sleepnow` when sleep comes back with the lid shut.
// The rules live in `SleepHelperCore` and `PMSetSleepControl` (Shared, unit-tested);
// this file wires them to the real system and to XPC.

private let log = Logger(subsystem: "com.opencaffeine.helper", category: "helper")

/// Runs `/usr/bin/pmset` with fixed arguments and gives up after 3 s. Returns its
/// standard output, or `nil` if it couldn't run, timed out, or exited non-zero.
private func pmset(_ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    let finished = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in finished.signal() }
    do {
        try process.run()
    } catch {
        log.error("Could not run pmset: \(String(describing: error), privacy: .public)")
        return nil
    }
    let command = arguments.joined(separator: " ")
    guard finished.wait(timeout: .now() + 3) == .success else {
        process.terminate()
        log.error("pmset \(command, privacy: .public) timed out")
        return nil
    }
    guard process.terminationStatus == 0 else {
        log.error("pmset \(command, privacy: .public) exited \(process.terminationStatus)")
        return nil
    }
    return String(bytes: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
}

/// One per app connection; hands requests to the core on the main queue.
private final class AppConnection: NSObject, LidSleepHelperProtocol {
    private let id: Int
    private let core: SleepHelperCore

    init(id: Int, core: SleepHelperCore) {
        self.id = id
        self.core = core
    }

    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { reply(self.core.request(disabled, by: self.id)) }
    }
}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let core: SleepHelperCore
    private let lock = NSLock()
    private var lastID = 0

    init(core: SleepHelperCore) {
        self.core = core
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let requirement = LidSleepHelper.requirement(forPeer: LidSleepHelper.appIdentifier) else {
            log.error("Helper is not signed with a team identity; refusing connections")
            return false
        }
        let id = lock.withLock {
            lastID += 1
            return lastID
        }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: LidSleepHelperProtocol.self)
        connection.exportedObject = AppConnection(id: id, core: core)
        connection.invalidationHandler = { [core] in
            DispatchQueue.main.async { core.connectionClosed(id) }
        }
        DispatchQueue.main.async { [core] in core.connectionOpened() }
        connection.resume()
        return true
    }
}

private let control = PMSetSleepControl(
    marker: URL(fileURLWithPath: "/Library/Application Support/Open Caffeine/helper-disabled-sleep"),
    maxWait: 2,
    run: { pmset($0) != nil },
    readSleepDisabled: { RootDomain.sleepDisabled },
    readSavedSleepDisabled: { PMSetSleepControl.savedSleepDisabled(fromPMSetOutput: pmset(["-g"])) },
    lidShouldSleep: { Clamshell.current()?.shouldSleep ?? false },
    now: { Date() },
    pause: { Thread.sleep(forTimeInterval: $0) }
)
private let core = SleepHelperCore(control: control, retryInterval: 5) { delay, work in
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
}
core.onIdle = {
    log.notice("Nothing left to do; exiting")
    exit(0)  // launchd starts the helper again on the next connection
}

// launchd sends SIGTERM when the helper is unregistered or the Mac shuts down, and
// SIGKILL once ExitTimeOut (30 s in the plist) runs out: put sleep back within that
// window, and exit non-zero if it couldn't be done (KeepAlive then restarts the
// helper if it is still loaded; the marker covers the rest). Even with pmset hanging,
// one attempt ends within about 8 s (3 s for pmset, up to 2 s of read-back, and 3 s
// more for a read already under way), so three attempts 1 s apart fit in 30 s.
signal(SIGTERM, SIG_IGN)
private let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termination.setEventHandler {
    core.terminate(attempts: 3, retryInterval: 1) { restored in
        log.notice("Terminating; sleep \(restored ? "restored" : "could not be restored", privacy: .public)")
        exit(restored ? 0 : 1)
    }
}
termination.resume()

core.recover()

private let delegate = ListenerDelegate(core: core)
private let listener = NSXPCListener(machServiceName: LidSleepHelper.label)
listener.delegate = delegate
listener.resume()
// Started at boot (RunAtLoad) only to run the recovery above: leave if nobody connects.
DispatchQueue.main.asyncAfter(deadline: .now() + 30) { core.idleCheck() }
dispatchMain()
