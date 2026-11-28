import Foundation

/// What "Stay awake with lid closed" is doing right now.
enum LidSleepState: Equatable {
    /// The switch is off or no session is running: the lid sleeps the Mac as usual.
    case off
    /// Closing the lid won't put the Mac to sleep.
    case active
    /// The switch is on, but a safety rule lets the Mac sleep for now.
    case paused(LidSleepPauseReason)
    /// The privileged helper isn't allowed yet (System Settings › Login Items).
    case needsApproval
    /// The helper couldn't change the setting; the lid still sleeps the Mac.
    case unavailable
    /// Lid mode ended but sleep couldn't be turned back on yet; retrying.
    case restoreFailed
}

enum LidSleepPauseReason: Equatable {
    case lowBattery
    case tooHot
}

extension LidSleepState {
    /// The line under the switch; `nil` when there's nothing to say.
    var caption: String? {
        let sleepsAnyway = String(
            localized: "Closing the lid will put your Mac to sleep.",
            comment: "Lid-closed caption: appended after a 'Paused — …' reason"
        )
        switch self {
        case .off, .active:
            return nil
        case .needsApproval:
            return String(
                localized: "Allow Open Caffeine in System Settings to finish setting this up.",
                comment: "Lid-closed caption: the privileged helper still needs approval in Login Items"
            )
        case .paused(.lowBattery):
            let percent = LidSleepPolicy.minimumBatteryPercent
            return String(
                localized: "Paused — battery is below \(percent)%. \(sleepsAnyway)",
                comment: "Lid-closed caption: %lld is the battery percent; %@ is 'Closing the lid will put your Mac…'"
            )
        case .paused(.tooHot):
            return String(
                localized: "Paused — your Mac is too hot. \(sleepsAnyway)",
                comment: "Lid-closed caption: %@ is 'Closing the lid will put your Mac to sleep.'"
            )
        case .unavailable:
            return String(
                localized: "Couldn't keep your Mac awake with the lid closed.",
                comment: "Lid-closed caption: the helper failed to block lid-close sleep"
            )
        case .restoreFailed:
            return String(
                localized: "Couldn't let your Mac sleep again yet — retrying.",
                comment: "Lid-closed caption: re-enabling sleep failed and will be retried"
            )
        }
    }

    /// Warnings mean the lid will sleep the Mac after all; the approval hint doesn't.
    var captionIsWarning: Bool {
        switch self {
        case .paused, .unavailable, .restoreFailed: return true
        case .off, .active, .needsApproval: return false
        }
    }
}

/// Everything that decides `LidSleepState`.
struct LidSleepConditions: Equatable {
    var enabled: Bool
    var sessionActive: Bool
    var helperApproved: Bool
    var power: PowerStatus
    var thermal: ProcessInfo.ThermalState
}

enum LidSleepPolicy {
    /// On battery, below this charge the lid may put the Mac to sleep again.
    static let minimumBatteryPercent = 20

    static func state(for conditions: LidSleepConditions) -> LidSleepState {
        guard conditions.enabled, conditions.sessionActive else { return .off }
        guard conditions.helperApproved else { return .needsApproval }
        if conditions.thermal == .serious || conditions.thermal == .critical { return .paused(.tooHot) }
        if conditions.power.onBattery, conditions.power.batteryPercent < minimumBatteryPercent {
            return .paused(.lowBattery)
        }
        return .active
    }
}
