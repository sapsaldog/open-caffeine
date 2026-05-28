import Foundation

/// Validates the custom-duration prompt's text input. Extracted from the NSAlert
/// presentation so the parsing rules are unit-testable.
enum CustomDurationParser {
    static func parse(_ text: String) -> CaffeineDuration? {
        guard let minutes = Int(text), minutes > 0 else { return nil }
        return .minutes(minutes)
    }
}
