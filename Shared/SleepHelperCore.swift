import Foundation

/// What the root helper can do to the system. The live version is
/// `PMSetSleepControl`; tests pass a fake, so the helper's rules are unit-tested.
protocol SleepControlling: AnyObject {
    var hasMarker: Bool { get }
    /// Durably records "sleep may be disabled" before it is. `false` if it couldn't.
    func writeMarker() -> Bool
    func removeMarker()
    /// Sets `disablesleep`; `true` only once the kernel reports the new value.
    func setSleepDisabled(_ disabled: Bool) -> Bool
    /// Puts the Mac to sleep if the lid is shut and macOS would sleep for that.
    func sleepIfLidIsClosed()
}

/// The root helper's rules. Call everything on one queue.
///
/// Sleep is one system-wide setting shared by every app connection: it is disabled
/// while anyone holds it and restored when the last holder lets go (asks, quits,
/// or crashes). The marker is written before disabling and removed only once sleep
/// is confirmed back, a failed restore is retried until it works, and a launch that
/// finds a marker undoes the earlier run. macOS decides about sleep when the lid
/// closes, so after an owned restore a shut lid gets the Mac to sleep.
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
    /// Set by an owned release (or recovery): once sleep is back, sleep a shut lid.
    private var sleepAfterRestore = false
    private var retryScheduled = false
    private var terminating = false

    init(control: SleepControlling, retryInterval: TimeInterval, schedule: @escaping Scheduler) {
        self.control = control
        self.retryInterval = retryInterval
        self.schedule = schedule
    }

    /// At launch: a marker left behind means an earlier run died with sleep disabled.
    func recover() {
        guard control.hasMarker else { return }
        restore(sleepingAShutLid: true)
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
            guard !terminating else { return false }
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

    /// launchd is stopping the helper (unregistered, shutdown). Refuse new holds,
    /// put sleep back — retrying a few times — and report whether that worked, so
    /// the process can exit non-zero (launchd restarts it if still loaded) when not.
    ///
    /// It never puts the Mac to sleep here: it can't tell a revoked approval (macOS
    /// keeps running) from a shutdown. The app can, and sleeps a shut lid itself
    /// when the helper goes away while it is still running.
    func terminate(attempts: Int, retryInterval: TimeInterval, completion: @escaping (Bool) -> Void) {
        terminating = true
        let wasHeld = !holders.isEmpty
        holders.removeAll()
        guard wasHeld || restorePending || control.hasMarker else { return completion(true) }
        attemptTermination(1, of: attempts, every: retryInterval, completion: completion)
    }

    private func attemptTermination(
        _ attempt: Int,
        of attempts: Int,
        every interval: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        if control.setSleepDisabled(false) {
            restorePending = false
            sleepAfterRestore = false
            control.removeMarker()
            return completion(true)
        }
        restorePending = true
        guard attempt < attempts else { return completion(false) }
        schedule(interval) { [weak self] in
            self?.attemptTermination(attempt + 1, of: attempts, every: interval, completion: completion)
        }
    }

    @discardableResult
    private func release(_ holder: Int) -> Bool {
        guard holders.remove(holder) != nil, holders.isEmpty else { return true }
        return restore(sleepingAShutLid: true)
    }

    private func disable() -> Bool {
        guard control.writeMarker() else { return false }
        guard control.setSleepDisabled(true) else {
            // pmset can fail late, so it may have applied anyway: get sleep back
            // (keeping the marker until that is confirmed). Nothing was held.
            restore(sleepingAShutLid: false)
            return false
        }
        restorePending = false
        sleepAfterRestore = false  // held again: a pending release no longer applies
        return true
    }

    @discardableResult
    private func restore(sleepingAShutLid: Bool) -> Bool {
        if sleepingAShutLid { sleepAfterRestore = true }
        guard control.setSleepDisabled(false) else {
            restorePending = true
            scheduleRetry()
            return false
        }
        restorePending = false
        control.removeMarker()
        if sleepAfterRestore {
            sleepAfterRestore = false
            control.sleepIfLidIsClosed()
        }
        return true
    }

    private func scheduleRetry() {
        guard !retryScheduled else { return }
        retryScheduled = true
        schedule(retryInterval) { [weak self] in
            guard let self else { return }
            retryScheduled = false
            guard restorePending, holders.isEmpty else { return }
            restore(sleepingAShutLid: false)
            idleCheck()
        }
    }
}
