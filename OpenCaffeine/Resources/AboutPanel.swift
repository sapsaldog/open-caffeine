import AppKit
import SwiftUI

/// A quiet, centered About window (design: 300×440) showing the app icon, name,
/// version, a one-line blurb, the maintainer/license line, License + View on
/// GitHub buttons, and the repository footer. The window is retained statically
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
    private static let repoURL = "https://github.com/sapsaldog/open-caffeine"
    private static let licenseURL = "https://github.com/sapsaldog/open-caffeine/blob/main/LICENSE"

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 4) {
            Image("AppGlyph")
                .resizable().frame(width: 104, height: 104)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 8)
                .padding(.bottom, 14)

            Text("Open Caffeine").font(.system(size: 22, weight: .bold))
            Text("Version \(version) (\(build))")
                .font(.system(size: 12)).foregroundStyle(.secondary)

            Text("An open-source menu-bar app that keeps your Mac awake for as long as you need.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.top, 12)
                .frame(maxWidth: 236)

            Text("Created by Hoon Choi\nReleased under the MIT License")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            HStack(spacing: 8) {
                Button("License") { open(Self.licenseURL) }
                Button("View on GitHub") { open(Self.repoURL) }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 20)

            Spacer(minLength: 0)
            Text("github.com/sapsaldog/open-caffeine")
                .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                .padding(.top, 18)
        }
        .padding(EdgeInsets(top: 38, leading: 28, bottom: 26, trailing: 28))
        .frame(width: 300, height: 440)
    }
}
