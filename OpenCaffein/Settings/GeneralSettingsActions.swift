import Foundation

/// Side-effecting actions behind the General settings controls, extracted from the
/// view so the login-item sync and dock-visibility wiring are unit-testable without
/// rendering SwiftUI. The view's bindings delegate here.
@MainActor
struct GeneralSettingsActions {
    let settings: AppSettings
    let loginItem: LoginItemManager
    let onDockVisibilityChange: (Bool) -> Void

    func setIconStyle(_ style: MenuBarIconStyle) {
        settings.iconStyle = style
    }

    func setStartAtLogin(_ enabled: Bool) {
        settings.startAtLogin = enabled
        loginItem.sync(enabled: enabled)
    }

    func setShowInDock(_ visible: Bool) {
        settings.showIconInDock = visible
        onDockVisibilityChange(visible)
    }
}
