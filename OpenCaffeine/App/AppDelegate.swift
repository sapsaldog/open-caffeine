import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private lazy var assertion = SleepAssertion(
        kind: { [settings] in SleepAssertionKind(keepDisplayAwake: settings.keepDisplayAwake) }
    )
    private(set) lazy var session = CaffeineSession(assertion: assertion)
    private let loginItem = LoginItemManager()
    private var menuBar: MenuBarController?
    private var hotKey: HotKeyService?
    private var batteryMonitor: BatteryMonitor?
    private lazy var preferencesWindow = PreferencesWindowController(
        onDockVisibilityChange: { [weak self] visible in self?.applyDockVisibility(visible) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        loginItem.sync(enabled: settings.startAtLogin)
        applyDockVisibility(settings.showIconInDock)
        installMenuBar()
        installHotKey()
        installBatteryMonitor()
        UpdaterService.shared.automaticallyChecksForUpdates = settings.autoCheckUpdates
        showInstructionMessageIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
    }

    func applyDockVisibility(_ visible: Bool) {
        NSApp.setActivationPolicy(AppLaunchLogic.activationPolicy(forDockVisible: visible))
    }

    private func installMenuBar() {
        let controller = MenuBarController(session: session, settings: settings)
        controller.onPreferences = { [weak self] in self?.preferencesWindow.show() }
        controller.onAbout = { AboutPanel.show() }
        controller.onStartScreensaver = { ScreenSaverLauncher.launch() }
        controller.onCustomDurationRequested = { [weak self] in
            guard let self else { return }
            if let duration = CustomDurationPrompt.ask() {
                try? self.session.start(duration)
            }
        }
        menuBar = controller
    }

    private func installHotKey() {
        hotKey = HotKeyService(session: session, settings: settings)
    }

    private func installBatteryMonitor() {
        let monitor = BatteryMonitor(
            threshold: { [settings] in settings.sleepBelowBatteryPercent },
            onLow: { [weak self] in self?.session.stop(reason: .lowBattery) }
        )
        monitor.startObserving()
        batteryMonitor = monitor
    }

    private func showInstructionMessageIfNeeded() {
        guard AppLaunchLogic.shouldShowInstructionMessage(
            showInstructionMessage: settings.showInstructionMessage,
            alreadyShown: settings.didShowInstructionMessage
        ) else { return }
        let alert = NSAlert()
        alert.messageText = "Open Caffeine is running in your menubar"
        alert.informativeText = """
        Click the coffee icon to start a session.
        Set a hotkey in Preferences for one-press toggle.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
        settings.didShowInstructionMessage = true
    }
}
