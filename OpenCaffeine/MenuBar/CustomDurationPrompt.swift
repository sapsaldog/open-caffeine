import AppKit

@MainActor
enum CustomDurationPrompt {
    static func ask() -> CaffeineDuration? {
        let alert = NSAlert()
        alert.messageText = "Custom Duration"
        alert.informativeText = "How many minutes should Open Caffeine keep your Mac awake?"
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = "60"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return CustomDurationParser.parse(input.stringValue)
    }
}
