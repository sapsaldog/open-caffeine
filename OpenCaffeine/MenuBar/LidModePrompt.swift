import AppKit

/// Explains "Stay awake with lid closed" before its one-time approval.
@MainActor
enum LidModePrompt {
    /// `true` to go ahead.
    static func confirm() -> Bool {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Keep your Mac awake with the lid closed?",
            comment: "Title of the alert that explains lid mode before its one-time approval"
        )
        alert.informativeText = String(
            localized: """
            Open Caffeine needs a one-time approval in System Settings. It only applies while a \
            session is running, and stops automatically below \(LidSleepPolicy.minimumBatteryPercent)% \
            battery or if your Mac gets hot.

            Don't put your Mac in a bag while it's awake. It can overheat.
            """,
            comment: "Body of the lid mode alert; the argument is the minimum battery percentage"
        )
        alert.addButton(withTitle: String(localized: "Continue", comment: "Lid mode alert: go on to the approval"))
        alert.addButton(withTitle: String(localized: "Cancel", comment: "Lid mode alert: dismiss"))
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Shown when the helper can't be registered at all (e.g. an unsigned build).
    static func showUnavailable() {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Lid mode isn't available in this build",
            comment: "Alert title when the lid mode helper can't be registered"
        )
        alert.informativeText = String(
            localized: "Open Caffeine couldn't set up its helper. This needs a signed build of the app.",
            comment: "Alert body when the lid mode helper can't be registered"
        )
        alert.addButton(withTitle: String(localized: "OK", comment: "Alert button: dismiss"))
        NSApp.activate()
        alert.runModal()
    }
}
