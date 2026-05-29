import Foundation

enum SessionState: Equatable {
    case idle
    case active(duration: CaffeineDuration, startedAt: Date)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    /// Remaining seconds, or `nil` for Forever sessions.
    /// Returns `0` once a finite session has elapsed.
    func remaining(now: Date = Date()) -> TimeInterval? {
        guard case .active(let duration, let startedAt) = self else { return nil }
        guard let total = duration.timeInterval else { return nil }
        let elapsed = now.timeIntervalSince(startedAt)
        return max(0, total - elapsed)
    }

    /// Ring-fill fraction for the menu panel: `0` when idle, `1` for an active
    /// Forever session, otherwise the remaining/total fraction clamped to 0...1.
    func progressShown(now: Date = Date()) -> Double {
        guard case .active(let duration, let startedAt) = self else { return 0 }
        guard let total = duration.timeInterval, total > 0 else { return 1 }
        let fraction = (total - now.timeIntervalSince(startedAt)) / total
        return min(1, max(0, fraction))
    }
}
