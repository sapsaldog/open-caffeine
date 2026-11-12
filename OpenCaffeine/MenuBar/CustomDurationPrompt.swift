import AppKit

@MainActor
enum CustomDurationPrompt {
    static func ask() -> CaffeineDuration? {
        let range = "1 to \(CustomDurationParser.maxMinutes.formatted()) (\(CustomDurationParser.maxDays) days)"
        var message = "How many minutes should Open Caffeine keep your Mac awake? Enter \(range)."
        var text = "60"

        // Ask again on invalid input instead of silently starting nothing.
        while true {
            let alert = NSAlert()
            alert.messageText = "Custom Duration"
            alert.informativeText = message
            alert.addButton(withTitle: "Start")
            alert.addButton(withTitle: "Cancel")

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
            input.stringValue = text
            alert.accessoryView = input
            alert.window.initialFirstResponder = input

            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            if let duration = CustomDurationParser.parse(input.stringValue) { return duration }
            text = input.stringValue
            message = "Enter a whole number of minutes from \(range)."
        }
    }
}
