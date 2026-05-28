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
}
