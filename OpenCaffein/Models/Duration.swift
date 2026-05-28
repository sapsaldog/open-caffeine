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
        case .forever: return "Forever"
        case .minutes(let minutes): return "\(minutes) min"
        case .hours(1): return "1 hour"
        case .hours(let hours): return "\(hours) hours"
        case .custom(let seconds):
            let minutes = Int(seconds / 60)
            return "Custom (\(minutes) min)"
        }
    }

    static let standardPresets: [CaffeineDuration] = [
        .forever,
        .minutes(5), .minutes(10), .minutes(15), .minutes(30), .minutes(45),
        .hours(1), .hours(2), .hours(4), .hours(6), .hours(12)
    ]
}
