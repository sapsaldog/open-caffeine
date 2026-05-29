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
        static let keepDisplayAwake = "keepDisplayAwake"
        static let appearanceMode = "appearanceMode"
        static let defaultDurationSeconds = "defaultDurationSeconds"
        static let sleepBelowBatteryPercent = "sleepBelowBatteryPercent"
        static let didShowInstructionMessage = "didShowInstructionMessage"
    }

    @AppStorage(Key.iconStyle) var iconStyleRaw: String = MenuBarIconStyle.coffeeType1.rawValue
    @AppStorage(Key.startAtLogin) var startAtLogin: Bool = false
    @AppStorage(Key.showIconInDock) var showIconInDock: Bool = false
    @AppStorage(Key.showInstructionMessage) var showInstructionMessage: Bool = false
    @AppStorage(Key.showCountdown) var showCountdown: Bool = true
    /// When true, also prevents the display from sleeping (the screen stays on).
    @AppStorage(Key.keepDisplayAwake) var keepDisplayAwake: Bool = true
    /// App appearance override: "auto" (default), "light", or "dark".
    @AppStorage(Key.appearanceMode) var appearanceModeRaw: String = AppearanceMode.auto.rawValue
    /// `-1` means Forever. Other values are seconds.
    @AppStorage(Key.defaultDurationSeconds) var defaultDurationSeconds: Int = -1
    /// `0` means disabled (no automatic stop on low battery).
    @AppStorage(Key.sleepBelowBatteryPercent) var sleepBelowBatteryPercent: Int = 0
    @AppStorage(Key.didShowInstructionMessage) var didShowInstructionMessage: Bool = false

    private var defaultsObserver: AnyCancellable?

    init() {
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
