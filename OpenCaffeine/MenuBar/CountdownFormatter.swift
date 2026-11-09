import Foundation

enum CountdownFormatter {
    /// - Parameter hideSeconds: When `true`, renders `h:mm` (hours:minutes),
    ///   rounding minutes *up* so the display never reads `0:00` while time remains.
    static func string(remaining: TimeInterval?, hideSeconds: Bool = false) -> String {
        guard let remaining else { return "∞" }
        let total = max(0, Int(remaining.rounded()))
        if hideSeconds {
            let totalMinutes = (total + 59) / 60
            return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
        }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
