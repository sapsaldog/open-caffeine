import Foundation

enum CaffeineDuration: Equatable, Hashable {
    case forever
    case minutes(Int)
    case hours(Int)
    case custom(seconds: TimeInterval)

    var timeInterval: TimeInterval? {
        switch self {
        case .forever: return nil
        case .minutes(let minutes): return TimeInterval(minutes) * 60
        case .hours(let hours): return TimeInterval(hours) * 3600
        case .custom(let seconds): return seconds
        }
    }

    var displayName: String {
        switch self {
        case .forever:
            return String(localized: "Forever", comment: "Session duration with no time limit")
        case .minutes(let minutes):
            return String(localized: "\(minutes) min", comment: "Session duration in minutes, e.g. 5 min")
        case .hours(1):
            return String(localized: "1 hour", comment: "Session duration of exactly one hour")
        case .hours(let hours):
            return String(localized: "\(hours) hours", comment: "Session duration in hours (2 or more), e.g. 12 hours")
        case .custom(let seconds):
            let minutes = Int(seconds / 60)
            return String(
                localized: "Custom (\(minutes) min)",
                comment: "User-chosen session duration, shown with its length in minutes"
            )
        }
    }

    /// Compact label for the menu-panel duration chips (∞, 5m, 1h …).
    var chipLabel: String {
        switch self {
        case .forever: return "∞"
        case .minutes(let minutes):
            return String(localized: "\(minutes)m", comment: "Compact duration chip in minutes, e.g. 5m; keep it short")
        case .hours(let hours):
            return String(localized: "\(hours)h", comment: "Compact duration chip in hours, e.g. 1h; keep it short")
        case .custom: return "···"
        }
    }

    static let standardPresets: [CaffeineDuration] = [
        .forever,
        .minutes(5), .minutes(10), .minutes(15), .minutes(30), .minutes(45),
        .hours(1), .hours(2), .hours(4), .hours(6), .hours(12)
    ]
}
