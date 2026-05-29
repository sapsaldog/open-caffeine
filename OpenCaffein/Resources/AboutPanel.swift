import AppKit
import SwiftUI

/// A quiet, centered About window (design: 300×400) showing the Espresso app
/// icon, name, version and a one-line blurb. The window is retained statically
/// so re-opening reuses it. Presentation shell — excluded from the coverage gate.
@MainActor
enum AboutPanel {
    private static var window: NSWindow?

    static func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 4) {
            Image("AppGlyph")
                .resizable().frame(width: 116, height: 116)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 8)
                .padding(.bottom, 14)

            Text("Open Caffein").font(.system(size: 22, weight: .bold))
            Text("Version \(version) (\(build))")
                .font(.system(size: 12)).foregroundStyle(.secondary)

            Text("A personal menu-bar utility that keeps your Mac awake for as long as you need.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.top, 12)
                .frame(maxWidth: 232)

            Spacer()
            Text("© 2026 · Personal use")
                .font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(width: 300, height: 400)
    }
}
