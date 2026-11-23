import Foundation
import os.log

// OpenCaffeineHelper runs as root, started by launchd on Open Caffeine's behalf
// (SMAppService.daemon). It does one thing: run `pmset -a disablesleep 1|0` when
// the signed Open Caffeine app asks — and put sleep back the moment that app goes
// away, so a crash or force-quit can never leave the Mac unable to sleep.

private let log = Logger(subsystem: "com.opencaffeine.helper", category: "helper")

/// Exists while this helper has sleep disabled. If the helper itself dies in that
/// state, its next start (at boot via RunAtLoad, or on demand) undoes it.
private let marker = URL(fileURLWithPath: "/Library/Application Support/Open Caffeine/helper-disabled-sleep")

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
        log.error("pmset \(arguments.joined(separator: " "), privacy: .public) exited with \(pmset.terminationStatus)")
        return false
    }
    return true
}

@discardableResult
private func setSystemSleepDisabled(_ disabled: Bool) -> Bool {
    guard runPMSet(["-a", "disablesleep", disabled ? "1" : "0"]) else { return false }
    updateMarker(disabled)
    log.notice("System sleep \(disabled ? "disabled" : "restored", privacy: .public)")
    return true
}

/// macOS decides about sleep when the lid closes, so once sleep is allowed again a
/// lid that is still shut may never be re-checked. Do what the closed lid would have.
private func sleepIfLidIsClosed() {
    guard Clamshell.current()?.shouldSleep == true else { return }
    log.notice("Lid is closed; putting the Mac to sleep")
    _ = runPMSet(["sleepnow"])
}

private func updateMarker(_ disabled: Bool) {
    let files = FileManager.default
    do {
        if disabled {
            try files.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: marker)
        } else if files.fileExists(atPath: marker.path) {
            try files.removeItem(at: marker)
        }
    } catch {
        log.error("Marker update failed: \(String(describing: error), privacy: .public)")
    }
}

/// One per app connection; remembers whether that connection disabled sleep.
/// All state is touched on the main queue.
private final class Session: NSObject, LidSleepHelperProtocol {
    private var disabledSleep = false

    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let accepted = setSystemSleepDisabled(disabled)
            if accepted { self.disabledSleep = disabled }
            reply(accepted)
        }
    }

    /// The app quit, crashed, or was killed: put sleep back if it was blocked, and
    /// with the lid shut, let the Mac sleep as the closed lid would have.
    func appWentAway() {
        if disabledSleep {
            log.notice("Open Caffeine went away with sleep disabled; restoring")
            guard setSystemSleepDisabled(false) else { return }
            disabledSleep = false
        }
        sleepIfLidIsClosed()
    }
}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private var openConnections = 0

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let requirement = LidSleepHelper.requirement(forPeer: LidSleepHelper.appIdentifier) else {
            log.error("Helper is not signed with a team identity; refusing connections")
            return false
        }
        connection.setCodeSigningRequirement(requirement)
        let session = Session()
        connection.exportedInterface = NSXPCInterface(with: LidSleepHelperProtocol.self)
        connection.exportedObject = session
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                session.appWentAway()
                self?.connectionClosed()
            }
        }
        DispatchQueue.main.async { self.openConnections += 1 }
        connection.resume()
        return true
    }

    private func connectionClosed() {
        openConnections -= 1
        exitIfIdle()
    }

    /// launchd starts the helper again on the next connection.
    func exitIfIdle() {
        guard openConnections <= 0 else { return }
        log.notice("No Open Caffeine connections; exiting")
        exit(0)
    }
}

if FileManager.default.fileExists(atPath: marker.path) {
    log.notice("Sleep was left disabled by an earlier helper run; restoring")
    if setSystemSleepDisabled(false) { sleepIfLidIsClosed() }
}

private let delegate = ListenerDelegate()
private let listener = NSXPCListener(machServiceName: LidSleepHelper.label)
listener.delegate = delegate
listener.resume()
// Started at boot (RunAtLoad) only to run the recovery above: leave if nobody connects.
DispatchQueue.main.asyncAfter(deadline: .now() + 30) { delegate.exitIfIdle() }
dispatchMain()
