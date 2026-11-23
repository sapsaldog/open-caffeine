import Foundation

/// What the root helper can do to the system. The live version runs `pmset` and
/// keeps a marker file; tests pass a fake, so the helper's rules are unit-tested.
protocol SleepControlling: AnyObject {
    var hasMarker: Bool { get }
    /// Durably records "sleep may be disabled" before it is. `false` if it couldn't.
    func writeMarker() -> Bool
    func removeMarker()
    /// `pmset -a disablesleep 1|0`; `false` if pmset failed.
    func setSleepDisabled(_ disabled: Bool) -> Bool
    /// Puts the Mac to sleep if the lid is shut and macOS would sleep for that.
    func sleepIfLidIsClosed()
}

/// The root helper's rules. Call everything on one queue.
///
/// Sleep is one system-wide setting shared by every app connection: it is disabled
/// while anyone holds it and restored when the last holder lets go (asks, quits,
/// or crashes). A restore that fails is retried until it works, and the marker
/// written before disabling lets the next launch undo a crash. macOS decides about
/// sleep when the lid closes, so after restoring, a shut lid gets the Mac to sleep.
final class SleepHelperCore {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    /// Runs when there is nothing left to do: no connections, holders, or pending restore.
    var onIdle: () -> Void = {}

    private let control: SleepControlling
    private let retryInterval: TimeInterval
    private let schedule: Scheduler
    private var holders: Set<Int> = []
    private var openConnections = 0
    private var restorePending = false
    private var retryScheduled = false

    init(control: SleepControlling, retryInterval: TimeInterval, schedule: @escaping Scheduler) {
        self.control = control
        self.retryInterval = retryInterval
        self.schedule = schedule
    }

    /// At launch: a marker left behind means an earlier run died with sleep disabled.
    func recover() {
        guard control.hasMarker else { return }
        restore()
    }

    func connectionOpened() {
        openConnections += 1
    }

    /// The app quit, crashed, was killed, or was rejected by the signing check.
    func connectionClosed(_ holder: Int) {
        openConnections -= 1
        release(holder)
        idleCheck()
    }

    /// - Returns: whether macOS now matches what this holder asked for.
    func request(_ disabled: Bool, by holder: Int) -> Bool {
        if disabled {
            guard !holders.contains(holder) else { return true }
            if holders.isEmpty {
                guard disable() else { return false }
            }
            holders.insert(holder)
            return true
        }
        guard holders.contains(holder) else { return holders.isEmpty ? !restorePending : true }
        return release(holder)
    }

    func idleCheck() {
        guard openConnections <= 0, holders.isEmpty, !restorePending else { return }
        onIdle()
    }

    /// launchd is stopping the helper (unregistered, shutdown): put sleep back first.
    func shutDown() {
        guard !holders.isEmpty || restorePending || control.hasMarker else { return }
        if control.setSleepDisabled(false) { control.removeMarker() }
    }

    @discardableResult
    private func release(_ holder: Int) -> Bool {
        guard holders.remove(holder) != nil, holders.isEmpty else { return true }
        return restore()
    }

    private func disable() -> Bool {
        guard control.writeMarker() else { return false }
        guard control.setSleepDisabled(true) else {
            // While a restore is still pending, sleep may well be disabled: keep the marker.
            if !restorePending { control.removeMarker() }
            return false
        }
        restorePending = false
        return true
    }

    @discardableResult
    private func restore() -> Bool {
        guard control.setSleepDisabled(false) else {
            restorePending = true
            scheduleRetry()
            return false
        }
        restorePending = false
        control.removeMarker()
        control.sleepIfLidIsClosed()
        return true
    }

    private func scheduleRetry() {
        guard !retryScheduled else { return }
        retryScheduled = true
        schedule(retryInterval) { [weak self] in
            guard let self else { return }
            retryScheduled = false
            guard restorePending, holders.isEmpty else { return }
            restore()
            idleCheck()
        }
    }
}
