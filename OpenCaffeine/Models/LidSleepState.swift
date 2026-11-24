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
        let sleepsAnyway = "Closing the lid will put your Mac to sleep."
        switch self {
        case .off, .active:
            return nil
        case .needsApproval:
            return "Allow Open Caffeine in System Settings to finish setting this up."
        case .paused(.lowBattery):
            return "Paused — battery is below \(LidSleepPolicy.minimumBatteryPercent)%. \(sleepsAnyway)"
        case .paused(.tooHot):
            return "Paused — your Mac is too hot. \(sleepsAnyway)"
        case .unavailable:
            return "Couldn't keep your Mac awake with the lid closed."
        case .restoreFailed:
            return "Couldn't let your Mac sleep again yet — retrying."
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
