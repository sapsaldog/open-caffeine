import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private lazy var assertion = SleepAssertion(
        kind: { [settings] in SleepAssertionKind(keepDisplayAwake: settings.keepDisplayAwake) }
    )
    private(set) lazy var session = CaffeineSession(assertion: assertion)
    private lazy var displayOff = DisplayOffAction(session: session, display: PMSetDisplaySleeper())
    private let hasLid = LidMonitor.hasLid
    private lazy var lidHelper = LidSleepHelperClient()
    private lazy var lidSleep = LidSleepController(
        conditions: { [unowned self] in self.lidConditions() },
        helper: lidHelper,
        display: PMSetDisplaySleeper(),
        sleepDisabledNow: { RootDomain.sleepDisabled }
    )
    private var lidMonitor: LidMonitor?
    private var approvalPoll: Timer?
    private var lidObservers: Set<AnyCancellable> = []
    private let loginItem = LoginItemManager()
    private var menuBar: MenuBarController?
    private var hotKey: HotKeyService?
    private var batteryMonitor: BatteryMonitor?
    private lazy var preferencesWindow = PreferencesWindowController(
        onDockVisibilityChange: { [weak self] visible in self?.applyDockVisibility(visible) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosting the unit tests: don't touch the menu bar, hot keys, updater,
        // login item, or the developer's real preferences.
        guard !AppLaunchLogic.isRunningAsTestHost(environment: ProcessInfo.processInfo.environment) else { return }
        loginItem.sync(enabled: settings.startAtLogin)
        applyDockVisibility(settings.showIconInDock)
        installMenuBar()
        installHotKey()
        installBatteryMonitor()
        installLidMode()
        UpdaterService.shared.automaticallyChecksForUpdates = settings.autoCheckUpdates
        showInstructionMessageIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
        // Lid mode needs nothing here: when this process's connection closes, the
        // helper puts sleep back (and sleeps a Mac whose lid is shut).
    }

    func applyDockVisibility(_ visible: Bool) {
        NSApp.setActivationPolicy(AppLaunchLogic.activationPolicy(forDockVisible: visible))
    }

    private func installMenuBar() {
        let controller = MenuBarController(session: session, settings: settings, lidSleep: lidSleep, hasLid: hasLid)
        controller.onPreferences = { [weak self] in self?.preferencesWindow.show() }
        controller.onAbout = { AboutPanel.show() }
        controller.onStartScreensaver = { ScreenSaverLauncher.launch() }
        controller.onDisplayOff = { [weak self] duration in self?.displayOff.perform(startingWith: duration) }
        controller.onLidModeChange = { [weak self] isOn in self?.setLidMode(isOn) }
        controller.onApproveLidHelper = { [weak self] in self?.lidHelper.openApprovalSettings() }
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
            onLow: { [weak self] in self?.session.stop(reason: .lowBattery) },
            onChange: { [weak self] in self?.refreshLidMode() }
        )
        monitor.startObserving()
        batteryMonitor = monitor
    }

    // MARK: Lid mode (MacBooks)

    private func lidConditions() -> LidSleepConditions {
        let enabled = hasLid && settings.stayAwakeWithLidClosed
        return LidSleepConditions(
            enabled: enabled,
            sessionActive: session.state.isActive,
            helperApproved: enabled && lidHelper.isApproved,
            power: SystemBatteryProvider().currentPowerStatus(),
            thermal: ProcessInfo.processInfo.thermalState
        )
    }

    private func refreshLidMode() {
        guard hasLid else { return }
        lidSleep.refresh()
    }

    private func installLidMode() {
        guard hasLid else { return }
        lidHelper.onInterrupted = { [weak self] in self?.lidSleep.helperInterrupted() }
        lidHelper.onInvalidated = { [weak self] in self?.lidSleep.helperInvalidated() }
        session.$state.receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshLidMode() }
            .store(in: &lidObservers)
        settings.objectWillChange.receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshLidMode() }
            .store(in: &lidObservers)
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshLidMode() }
            .store(in: &lidObservers)
        lidSleep.$state.receive(on: RunLoop.main)
            .sink { [weak self] state in self?.pollForApproval(state == .needsApproval) }
            .store(in: &lidObservers)
        let monitor = LidMonitor { [weak self] in
            self?.lidSleep.lidDidClose(externalDisplayCount: LidMonitor.externalDisplayCount())
        }
        monitor.start()
        lidMonitor = monitor
    }

    /// The user flipped the switch. The first time, explain and register the helper.
    private func setLidMode(_ isOn: Bool) {
        guard isOn else {
            settings.stayAwakeWithLidClosed = false
            return
        }
        if !lidHelper.isApproved {
            menuBar?.closePanel()
            guard LidModePrompt.confirm() else { return }
            switch lidHelper.register() {
            case .approved:
                break
            case .needsApproval:
                lidHelper.openApprovalSettings()
            case .failed:
                LidModePrompt.showUnavailable()
                return
            }
        }
        settings.stayAwakeWithLidClosed = true
    }

    /// Nothing tells the app when the user allows the helper in System Settings,
    /// so check every few seconds while waiting for it.
    private func pollForApproval(_ waiting: Bool) {
        approvalPoll?.invalidate()
        approvalPoll = nil
        guard waiting else { return }
        approvalPoll = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLidMode() }
        }
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
