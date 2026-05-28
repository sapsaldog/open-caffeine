import Foundation

enum CountdownFormatter {
    static func string(remaining: TimeInterval?) -> String {
        guard let remaining else { return "∞" }
        let total = Int(remaining.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
