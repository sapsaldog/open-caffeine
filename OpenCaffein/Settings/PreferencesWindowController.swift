import AppKit
import SwiftUI

/// Hosts the SwiftUI `PreferencesScene` in a self-managed AppKit window.
///
/// An AppKit menubar app can't trigger SwiftUI's `Settings` scene without the
/// macOS 14+ "Please use SettingsLink" runtime warning, so we own the window
/// directly and drop the `showSettingsWindow:` selector entirely.
@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    private let onDockVisibilityChange: (Bool) -> Void

    init(onDockVisibilityChange: @escaping (Bool) -> Void) {
        self.onDockVisibilityChange = onDockVisibilityChange
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(
            rootView: PreferencesScene(onDockVisibilityChange: onDockVisibilityChange)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
