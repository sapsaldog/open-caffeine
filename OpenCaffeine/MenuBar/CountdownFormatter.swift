import Foundation

enum CountdownFormatter {
    /// - Parameter hideSeconds: When `true`, renders `h:mm` (hours:minutes),
    ///   rounding minutes *up* so the display never reads `0:00` while time remains.
    static func string(remaining: TimeInterval?, hideSeconds: Bool = false) -> String {
        guard let remaining else { return "∞" }
        let clamped = max(0, remaining)
        if hideSeconds {
            let totalMinutes = Int((clamped / 60).rounded(.up))
            return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
        }
        let total = Int(clamped.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
