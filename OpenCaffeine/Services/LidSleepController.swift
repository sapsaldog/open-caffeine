import Combine
import Foundation
import os.log

/// Seam over the privileged helper that flips `pmset disablesleep`. The live
/// implementation is `LidSleepHelperClient`.
protocol SleepDisabling: AnyObject {
    /// `completion` runs on the main queue with whether macOS now matches the request.
    func setSleepDisabled(_ disabled: Bool, completion: @escaping (Bool) -> Void)
}

/// Applies "Stay awake with lid closed": asks the helper to block lid-close sleep
/// while `LidSleepPolicy` allows it, puts sleep back the moment it doesn't, and
/// turns the built-in display off when the lid closes.
///
/// macOS's setting is tracked as *desired* (from the policy), *confirmed* (by the
/// helper), and *in flight*. One request at a time, so replies can't cross; a
/// refused one is retried with backoff; a changed answer goes out right away.
/// What happens to a shut lid when sleep comes back is the helper's job.
final class LidSleepController: ObservableObject {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    @Published private(set) var state: LidSleepState = .off

    private let conditions: () -> LidSleepConditions
    private let helper: SleepDisabling
    private let display: DisplaySleeping
    private let schedule: Scheduler
    private let log = Logger(subsystem: "com.opencaffeine", category: "lid")

    private var wanted: LidSleepState = .off
    /// The `disablesleep` value the policy wants.
    private var desired = false
    /// What the helper last confirmed; `nil` once it restarted and nobody knows.
    private var confirmed: Bool? = false
    /// The request on the wire, if any.
    private var inFlight: Bool?
    /// Consecutive refused requests: drive the backoff and the warnings.
    private var failures = 0
    private var retryPending = false
    /// Bumped to cancel a waiting retry.
    private var retryGeneration = 0

    init(
        conditions: @escaping () -> LidSleepConditions,
        helper: SleepDisabling,
        display: DisplaySleeping,
        schedule: @escaping Scheduler = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.conditions = conditions
        self.helper = helper
        self.display = display
        self.schedule = schedule
    }

    /// Re-evaluates after any input changed: session, switch, power, heat, approval.
    func refresh() {
        wanted = LidSleepPolicy.state(for: conditions())
        let wantsDisabled = wanted == .active
        if wantsDisabled != desired {
            desired = wantsDisabled
            failures = 0
            cancelRetry()  // a changed answer goes out now, not after the backoff
        }
        reconcile()
        publish()
    }

    /// The helper crashed and launchd restarted it: what it holds is unknown now.
    func helperInterrupted() {
        confirmed = nil
        cancelRetry()
        reconcile()
        publish()
    }

    /// The helper can't be reached anymore (unregistered or refused). It puts
    /// sleep back on its way out, so it holds nothing for us.
    func helperInvalidated() {
        confirmed = false
        refresh()
    }

    /// The lid just closed. With nothing else lit, make sure the built-in display
    /// is off rather than glowing under the lid. `displaysleepnow` blanks every
    /// display, so leave it alone when an external monitor is in use.
    func lidDidClose(externalDisplayCount: Int) {
        guard state == .active, externalDisplayCount == 0 else { return }
        do {
            try display.sleepDisplayNow()
        } catch {
            log.error("Lid closed, display sleep failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func reconcile() {
        guard inFlight == nil, !retryPending, confirmed != desired else { return }
        let value = desired
        inFlight = value
        helper.setSleepDisabled(value) { [weak self] accepted in
            self?.finish(value, accepted: accepted)
        }
    }

    private func finish(_ value: Bool, accepted: Bool) {
        inFlight = nil
        if accepted {
            confirmed = value
            failures = 0
        } else {
            failures += 1
            log.error("Helper refused disablesleep=\(value, privacy: .public) (\(self.failures) in a row); retrying")
            scheduleRetry()
        }
        reconcile()
        publish()
    }

    private func scheduleRetry() {
        retryPending = true
        let generation = retryGeneration
        schedule(min(60, pow(2, Double(failures)))) { [weak self] in
            guard let self, generation == retryGeneration else { return }
            retryPending = false
            reconcile()
            publish()
        }
    }

    private func cancelRetry() {
        retryGeneration += 1
        retryPending = false
    }

    private func publish() {
        let shown: LidSleepState
        if desired {
            shown = confirmed == true ? .active : (failures > 0 ? .unavailable : .off)
        } else if confirmed != false, failures > 0 {
            shown = .restoreFailed
        } else {
            shown = wanted
        }
        if state != shown { state = shown }
    }
}
