import Combine
import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let iconStyle = "iconStyle"
        static let startAtLogin = "startAtLogin"
        static let showIconInDock = "showIconInDock"
        static let showInstructionMessage = "showInstructionMessage"
        static let showCountdown = "showCountdown"
        static let hideCountdownSeconds = "hideCountdownSeconds"
        static let keepDisplayAwake = "keepDisplayAwake"
        static let appearanceMode = "appearanceMode"
        static let autoCheckUpdates = "autoCheckUpdates"
        static let updateChannel = "updateChannel"
        static let defaultDurationSeconds = "defaultDurationSeconds"
        static let sleepBelowBatteryPercent = "sleepBelowBatteryPercent"
        static let didShowInstructionMessage = "didShowInstructionMessage"
    }

    // Default values live in `init`, where the backing store is chosen.
    @AppStorage var iconStyleRaw: String
    @AppStorage var startAtLogin: Bool
    @AppStorage var showIconInDock: Bool
    @AppStorage var showInstructionMessage: Bool
    @AppStorage var showCountdown: Bool
    /// When true, countdowns render as `h:mm` without the seconds field.
    @AppStorage var hideCountdownSeconds: Bool
    /// When true, also prevents the display from sleeping (the screen stays on).
    @AppStorage var keepDisplayAwake: Bool
    /// App appearance override: "auto" (default), "light", or "dark".
    @AppStorage var appearanceModeRaw: String
    /// Software-update preferences (UI only — no updater backend is wired yet).
    @AppStorage var autoCheckUpdates: Bool
    @AppStorage var updateChannelRaw: String
    /// `-1` means Forever. Other values are seconds.
    @AppStorage var defaultDurationSeconds: Int
    /// `0` means disabled (no automatic stop on low battery).
    @AppStorage var sleepBelowBatteryPercent: Int
    @AppStorage var didShowInstructionMessage: Bool

    private var defaultsObserver: AnyCancellable?

    /// Settings live in `defaults`. The app uses `.standard`; tests pass a
    /// throwaway suite so they never touch the real preferences.
    init(defaults store: UserDefaults = .standard) {
        _iconStyleRaw = AppStorage(wrappedValue: MenuBarIconStyle.coffeeType1.rawValue, Key.iconStyle, store: store)
        _startAtLogin = AppStorage(wrappedValue: false, Key.startAtLogin, store: store)
        _showIconInDock = AppStorage(wrappedValue: false, Key.showIconInDock, store: store)
        _showInstructionMessage = AppStorage(wrappedValue: false, Key.showInstructionMessage, store: store)
        _showCountdown = AppStorage(wrappedValue: true, Key.showCountdown, store: store)
        _hideCountdownSeconds = AppStorage(wrappedValue: false, Key.hideCountdownSeconds, store: store)
        _keepDisplayAwake = AppStorage(wrappedValue: true, Key.keepDisplayAwake, store: store)
        _appearanceModeRaw = AppStorage(wrappedValue: AppearanceMode.auto.rawValue, Key.appearanceMode, store: store)
        _autoCheckUpdates = AppStorage(wrappedValue: true, Key.autoCheckUpdates, store: store)
        _updateChannelRaw = AppStorage(wrappedValue: UpdateChannel.stable.rawValue, Key.updateChannel, store: store)
        _defaultDurationSeconds = AppStorage(wrappedValue: -1, Key.defaultDurationSeconds, store: store)
        _sleepBelowBatteryPercent = AppStorage(wrappedValue: 0, Key.sleepBelowBatteryPercent, store: store)
        _didShowInstructionMessage = AppStorage(wrappedValue: false, Key.didShowInstructionMessage, store: store)

        // @AppStorage drives SwiftUI view updates but does not forward through
        // ObservableObject.objectWillChange. Bridge UserDefaults changes so
        // non-View subscribers (menubar controller, etc.) get Combine signals.
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var iconStyle: MenuBarIconStyle {
        get { MenuBarIconStyle(rawValue: iconStyleRaw) ?? .coffeeType1 }
        set { iconStyleRaw = newValue.rawValue }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .auto }
        set { appearanceModeRaw = newValue.rawValue }
    }

    var updateChannel: UpdateChannel {
        get { UpdateChannel(rawValue: updateChannelRaw) ?? .stable }
        set { updateChannelRaw = newValue.rawValue }
    }

    /// Round-trips through `defaultDurationSeconds`. Reconstructs canonical
    /// preset cases when the stored value matches one, so Picker tag matching
    /// against `CaffeineDuration.standardPresets` works after a relaunch.
    var defaultDuration: CaffeineDuration {
        get {
            if defaultDurationSeconds < 0 { return .forever }
            let seconds = defaultDurationSeconds
            if let preset = CaffeineDuration.standardPresets.first(where: {
                $0.timeInterval.map { Int($0) } == seconds
            }) {
                return preset
            }
            return .custom(seconds: TimeInterval(seconds))
        }
        set {
            defaultDurationSeconds = newValue.timeInterval.map { Int($0) } ?? -1
        }
    }
}
