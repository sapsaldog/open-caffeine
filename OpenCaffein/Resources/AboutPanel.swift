import AppKit

@MainActor
enum AboutPanel {
    static func show() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let credits = NSAttributedString(
            string: "An open-source tool that helps keep your Mac awake.",
            attributes: [.foregroundColor: NSColor.labelColor]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Open Caffein",
            .applicationVersion: version,
            .credits: credits
        ])
    }
}
