import AppKit

/// Explains "Stay awake with lid closed" before its one-time approval.
@MainActor
enum LidModePrompt {
    /// `true` to go ahead.
    static func confirm() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Keep your Mac awake with the lid closed?"
        alert.informativeText = """
        Open Caffeine needs a one-time approval in System Settings. It only applies while a \
        session is running, and stops automatically below \(LidSleepPolicy.minimumBatteryPercent)% \
        battery or if your Mac gets hot.

        Don't put your Mac in a bag while it's awake. It can overheat.
        """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Shown when the helper can't be registered at all (e.g. an unsigned build).
    static func showUnavailable() {
        let alert = NSAlert()
        alert.messageText = "Lid mode isn't available in this build"
        alert.informativeText = "Open Caffeine couldn't set up its helper. This needs a signed build of the app."
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }
}
