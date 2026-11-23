import Combine
import Foundation
import os.log

/// Seam over the privileged helper that flips `pmset disablesleep`. The live
/// implementation is `LidSleepHelperClient`.
protocol SleepDisabling: AnyObject {
    /// `completion` runs on the main queue with whether macOS accepted the change.
    func setSleepDisabled(_ disabled: Bool, completion: @escaping (Bool) -> Void)
}

/// Seam over "put the Mac to sleep now". The live implementation lives in `SystemAdapters`.
protocol SystemSleeping {
    func sleepNow() throws
}

/// Applies "Stay awake with lid closed": asks the helper to block lid-close
/// sleep while `LidSleepPolicy` allows it, puts sleep back the moment it doesn't,
/// turns the built-in display off when the lid closes, and puts the Mac to sleep
/// if lid mode ends while the lid is still shut.
final class LidSleepController: ObservableObject {
    @Published private(set) var state: LidSleepState = .off

    private let conditions: () -> LidSleepConditions
    private let helper: SleepDisabling
    private let display: DisplaySleeping
    private let system: SystemSleeping
    /// Lid closed and macOS would sleep for it (no closed-display mode).
    private let closedLidShouldSleep: () -> Bool
    /// What macOS was last told; the helper is only called when this changes.
    private var sleepDisabled = false
    private let log = Logger(subsystem: "com.opencaffeine", category: "lid")

    init(
        conditions: @escaping () -> LidSleepConditions,
        helper: SleepDisabling,
        display: DisplaySleeping,
        system: SystemSleeping,
        closedLidShouldSleep: @escaping () -> Bool
    ) {
        self.conditions = conditions
        self.helper = helper
        self.display = display
        self.system = system
        self.closedLidShouldSleep = closedLidShouldSleep
    }

    /// Re-evaluates after any input changed: session, switch, power, heat, approval.
    func refresh() {
        let wanted = LidSleepPolicy.state(for: conditions())
        if state != wanted { state = wanted }
        apply(disabled: wanted == .active)
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

    /// Puts normal sleep back, e.g. when the app quits. (The helper also does this
    /// on its own if the app disappears without saying goodbye.)
    func restoreSleep() {
        apply(disabled: false)
    }

    private func apply(disabled: Bool) {
        guard disabled != sleepDisabled else { return }
        sleepDisabled = disabled
        helper.setSleepDisabled(disabled) { [weak self] accepted in
            guard let self else { return }
            guard accepted else {
                log.error("Helper refused disablesleep=\(disabled, privacy: .public); will retry")
                sleepDisabled = !disabled  // macOS kept its old setting
                if disabled { state = .unavailable }
                return
            }
            if !disabled { sleepIfLidIsClosed() }
        }
    }

    /// macOS decides about sleep when the lid closes. Lid mode just ended with the
    /// lid still shut (session over, low battery, heat, quitting), and nothing may
    /// re-check it, so put the Mac to sleep as a closed lid normally would.
    private func sleepIfLidIsClosed() {
        guard closedLidShouldSleep() else { return }
        log.notice("Lid mode ended with the lid closed; sleeping now")
        do {
            try system.sleepNow()
        } catch {
            log.error("Sleep request failed: \(String(describing: error), privacy: .public)")
        }
    }
}
