import Foundation

/// Decides what the menu-bar button shows for a given session/settings state.
/// Extracted from `MenuBarController` so the display rules are unit-testable
/// without an `NSStatusItem`.
enum MenuBarIconModel {
    static func title(isActive: Bool, showCountdown: Bool, remaining: TimeInterval?) -> String {
        guard isActive, showCountdown else { return "" }
        return " " + CountdownFormatter.string(remaining: remaining)
    }
}
