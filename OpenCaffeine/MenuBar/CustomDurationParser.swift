import Foundation

/// Validates the custom-duration prompt's text input. Extracted from the NSAlert
/// presentation so the parsing rules are unit-testable.
enum CustomDurationParser {
    /// Longest custom session. Longer stays are what Forever is for, and the cap
    /// keeps the countdown arithmetic far away from integer overflow.
    static let maxDays = 7
    static let maxMinutes = maxDays * 24 * 60

    static func parse(_ text: String) -> CaffeineDuration? {
        guard let minutes = Int(text), (1...maxMinutes).contains(minutes) else { return nil }
        return .minutes(minutes)
    }
}
