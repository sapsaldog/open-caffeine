import Foundation

/// Decides what the menu-bar button shows for a given session/settings state.
/// Extracted from `MenuBarController` so the display rules are unit-testable
/// without an `NSStatusItem`.
enum MenuBarIconModel {
    static func title(
        isActive: Bool,
        showCountdown: Bool,
        hideSeconds: Bool,
        remaining: TimeInterval?
    ) -> String {
        guard isActive, showCountdown else { return "" }
        return " " + CountdownFormatter.string(remaining: remaining, hideSeconds: hideSeconds)
    }

    /// When the title should refresh: first after `delay`, then every `interval`.
    struct RefreshSchedule: Equatable {
        let delay: TimeInterval
        let interval: TimeInterval
    }

    /// Fire this long after a minute boundary so the refreshed `h:mm` title
    /// already shows the new minute.
    static let minuteBoundaryLeeway: TimeInterval = 0.05

    /// `nil` when the title can't change (inactive, countdown off, or Forever).
    /// With seconds shown the title changes every second. With seconds hidden it
    /// changes only as `remaining` crosses a whole minute, so refreshes line up
    /// with those boundaries instead of firing 60 times per visible change.
    static func refreshSchedule(
        isActive: Bool,
        showCountdown: Bool,
        hideSeconds: Bool,
        remaining: TimeInterval?
    ) -> RefreshSchedule? {
        guard isActive, showCountdown, let remaining else { return nil }
        guard hideSeconds else { return RefreshSchedule(delay: 1, interval: 1) }
        let untilBoundary = remaining.truncatingRemainder(dividingBy: 60)
        let delay = (untilBoundary > 0 ? untilBoundary : 60) + minuteBoundaryLeeway
        return RefreshSchedule(delay: delay, interval: 60)
    }
}
