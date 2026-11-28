import AppKit

@MainActor
enum CustomDurationPrompt {
    static func ask() -> CaffeineDuration? {
        let maxMinutes = CustomDurationParser.maxMinutes.formatted()
        let maxDays = String(
            localized: "\(CustomDurationParser.maxDays) days",
            comment: "Longest custom duration in days, shown in parentheses: (7 days)"
        )
        let range = String(
            localized: "1 to \(maxMinutes) (\(maxDays))",
            comment: "Allowed custom duration range in minutes, e.g. 1 to 10,080 (7 days)"
        )
        var message = String(
            localized: "How many minutes should Open Caffeine keep your Mac awake? Enter \(range).",
            comment: "Custom duration prompt text; the argument is the allowed range"
        )
        var text = "60"

        // Ask again on invalid input instead of silently starting nothing.
        while true {
            let alert = NSAlert()
            alert.messageText = String(localized: "Custom Duration", comment: "Custom duration prompt title")
            alert.informativeText = message
            alert.addButton(withTitle: String(localized: "Start", comment: "Custom duration prompt: start the session"))
            alert.addButton(withTitle: String(localized: "Cancel", comment: "Custom duration prompt: dismiss"))

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
            input.stringValue = text
            alert.accessoryView = input
            alert.window.initialFirstResponder = input

            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            if let duration = CustomDurationParser.parse(input.stringValue) { return duration }
            text = input.stringValue
            message = String(
                localized: "Enter a whole number of minutes from \(range).",
                comment: "Custom duration prompt text after invalid input; the argument is the allowed range"
            )
        }
    }
}
