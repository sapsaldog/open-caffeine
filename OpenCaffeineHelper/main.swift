import Foundation
import os.log

// OpenCaffeineHelper runs as root, started by launchd on Open Caffeine's behalf
// (SMAppService.daemon). It can only run `pmset -a disablesleep 1|0` for the signed
// Open Caffeine app, and `pmset sleepnow` when sleep comes back with the lid shut.
// The rules live in `SleepHelperCore` (Shared, unit-tested); this file is plumbing.

private let log = Logger(subsystem: "com.opencaffeine.helper", category: "helper")

/// `pmset`, plus the marker file that lets a later launch undo a crash.
private final class LiveSleepControl: SleepControlling {
    private let marker = URL(fileURLWithPath: "/Library/Application Support/Open Caffeine/helper-disabled-sleep")

    var hasMarker: Bool { FileManager.default.fileExists(atPath: marker.path) }

    func writeMarker() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: marker.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data().write(to: marker, options: .atomic)
            return true
        } catch {
            log.error("Could not write the recovery marker: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    func removeMarker() {
        guard hasMarker else { return }
        do {
            try FileManager.default.removeItem(at: marker)
        } catch {
            log.error("Could not remove the recovery marker: \(String(describing: error), privacy: .public)")
        }
    }

    func setSleepDisabled(_ disabled: Bool) -> Bool {
        let accepted = runPMSet(["-a", "disablesleep", disabled ? "1" : "0"])
        if accepted { log.notice("System sleep \(disabled ? "disabled" : "restored", privacy: .public)") }
        return accepted
    }

    func sleepIfLidIsClosed() {
        guard Clamshell.current()?.shouldSleep == true else { return }
        log.notice("Lid is closed; putting the Mac to sleep")
        _ = runPMSet(["sleepnow"])
    }

    private func runPMSet(_ arguments: [String]) -> Bool {
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = arguments
        do {
            try pmset.run()
        } catch {
            log.error("Could not run pmset: \(String(describing: error), privacy: .public)")
            return false
        }
        pmset.waitUntilExit()
        guard pmset.terminationStatus == 0 else {
            log.error("pmset \(arguments.joined(separator: " "), privacy: .public) exited \(pmset.terminationStatus)")
            return false
        }
        return true
    }
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

private let core = SleepHelperCore(control: LiveSleepControl(), retryInterval: 5) { delay, work in
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
}
core.onIdle = {
    log.notice("Nothing left to do; exiting")
    exit(0)  // launchd starts the helper again on the next connection
}

// launchd sends SIGTERM when the helper is unregistered or the Mac shuts down.
signal(SIGTERM, SIG_IGN)
private let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termination.setEventHandler {
    core.shutDown()
    exit(0)
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
