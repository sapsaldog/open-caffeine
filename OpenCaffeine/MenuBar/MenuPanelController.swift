import AppKit
import SwiftUI

/// Floats the menu surface in a borderless, transparent panel positioned under
/// the status-bar button. A transparent window lets the SwiftUI `.glassEffect`
/// refract the desktop behind it — an `NSPopover`'s opaque backdrop cannot.
/// Dismisses on any click outside. Presentation shell — excluded from coverage.
@MainActor
final class MenuPanelController {
    private let panel: NSPanel
    private var clickMonitor: Any?
    private let onOpen: @MainActor () -> Void
    private let onClose: @MainActor () -> Void

    /// `onOpen` runs before the panel appears and `onClose` after it is hidden, so
    /// per-open work (like the panel clock) runs only while the panel is visible.
    init(
        rootView: some View,
        onOpen: @escaping @MainActor () -> Void = {},
        onClose: @escaping @MainActor () -> Void = {}
    ) {
        self.onOpen = onOpen
        self.onClose = onClose
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame.size = hosting.fittingSize
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(below button: NSStatusBarButton) {
        if isVisible { close() } else { open(below: button) }
    }

    func open(below button: NSStatusBarButton) {
        guard let hosting = panel.contentView else { return }
        onOpen()
        let size = hosting.fittingSize
        panel.setContentSize(size)
        if let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            panel.setFrameOrigin(NSPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 6))
        }
        panel.orderFrontRegardless()
        installMonitor()
    }

    func close() {
        removeMonitor()
        panel.orderOut(nil)
        onClose()
    }

    private func installMonitor() {
        removeMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func removeMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }
}
