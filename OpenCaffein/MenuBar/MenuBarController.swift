import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let session: CaffeineSession
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private var panel: MenuPanelController!
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: Timer?
    private var lastKeepDisplayAwake = false

    var onPreferences: (() -> Void)?
    var onAbout: (() -> Void)?
    var onStartScreensaver: (() -> Void)?
    var onCustomDurationRequested: (() -> Void)?

    init(session: CaffeineSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configurePanel()
        configureButton()
        observeSession()
        observeSettings()
        applyAppearance()
        refreshIcon()
    }

    private func configurePanel() {
        let root = MenuPanelView(
            session: session,
            settings: settings,
            onScreensaver: { [weak self] in self?.onStartScreensaver?() },
            onPreferences: { [weak self] in self?.onPreferences?() },
            onAbout: { [weak self] in self?.onAbout?() },
            onCustom: { [weak self] in self?.onCustomDurationRequested?() },
            onQuit: { NSApp.terminate(nil) },
            dismiss: { [weak self] in self?.panel.close() }
        )
        panel = MenuPanelController(rootView: root)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePanel)
        button.target = self
        updateMenuBarImage()
    }

    private func updateMenuBarImage() {
        statusItem.button?.image = CoffeeGlyphRenderer.image(settings.iconStyle)
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        panel.toggle(below: button)
    }

    private func observeSession() {
        session.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIcon()
                self?.scheduleTickIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func observeSettings() {
        lastKeepDisplayAwake = settings.keepDisplayAwake
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshIcon()
                self.updateMenuBarImage()
                self.applyAppearance()
                self.reapplyAssertionIfDisplayPreferenceChanged()
            }
            .store(in: &cancellables)
    }

    private func reapplyAssertionIfDisplayPreferenceChanged() {
        guard settings.keepDisplayAwake != lastKeepDisplayAwake else { return }
        lastKeepDisplayAwake = settings.keepDisplayAwake
        session.reapplyAssertionIfActive()
    }

    private func applyAppearance() {
        NSApp.appearance = settings.appearanceMode.nsAppearance
    }

    private func scheduleTickIfNeeded() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard session.state.isActive,
              session.state.remaining() != nil,
              settings.showCountdown else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshIcon() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        button.title = MenuBarIconModel.title(
            isActive: session.state.isActive,
            showCountdown: settings.showCountdown,
            remaining: session.state.remaining()
        )
    }
}
