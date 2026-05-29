import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let session: CaffeineSession
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private let builder = MenuBuilder()
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
        configureBuilder()
        refreshMenu()
        observeSession()
        observeSettings()
        refreshIcon()
    }

    private func configureBuilder() {
        builder.target = self
        builder.startAction = #selector(handleStart(_:))
        builder.screensaverAction = #selector(handleScreensaver)
        builder.preferencesAction = #selector(handlePreferences)
        builder.aboutAction = #selector(handleAbout)
        builder.quitAction = #selector(handleQuit)
    }

    private func observeSession() {
        session.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIcon()
                self?.refreshMenu()
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
                self.reapplyAssertionIfDisplayPreferenceChanged()
            }
            .store(in: &cancellables)
    }

    private func reapplyAssertionIfDisplayPreferenceChanged() {
        guard settings.keepDisplayAwake != lastKeepDisplayAwake else { return }
        lastKeepDisplayAwake = settings.keepDisplayAwake
        session.reapplyAssertionIfActive()
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
        let style = settings.iconStyle
        let assetName = MenuBarIconModel.assetName(isActive: session.state.isActive, style: style)
        let image = NSImage(named: assetName) ?? NSImage(named: style.idleAssetName)
        image?.isTemplate = true
        button.image = image
        button.title = MenuBarIconModel.title(
            isActive: session.state.isActive,
            showCountdown: settings.showCountdown,
            remaining: session.state.remaining()
        )
    }

    private func refreshMenu() {
        let current: CaffeineDuration?
        if case .active(let duration, _) = session.state { current = duration } else { current = nil }
        statusItem.menu = builder.build(currentDuration: current)
    }

    @objc private func handleStart(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? CaffeineDuration {
            try? session.start(preset)
            return
        }
        if sender.representedObject as? String == "custom" {
            onCustomDurationRequested?()
        }
    }

    @objc private func handleScreensaver() { onStartScreensaver?() }
    @objc private func handlePreferences() { onPreferences?() }
    @objc private func handleAbout() { onAbout?() }
    @objc private func handleQuit() { NSApp.terminate(nil) }
}
