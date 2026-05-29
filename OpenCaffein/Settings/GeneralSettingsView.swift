import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    let loginItem: LoginItemManager
    let onDockVisibilityChange: (Bool) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsGroupLabel(text: "Appearance")
                SettingsGroup {
                    SettingsRow(
                        "Appearance",
                        subtitle: "Auto follows your macOS Light & Dark setting.",
                        first: true
                    ) {
                        MacSegmentedControl(
                            selection: appearanceModeBinding,
                            values: AppearanceMode.allCases
                        ) { mode, selected in
                            HStack(spacing: 5) {
                                if let icon = icon(for: mode) {
                                    Image(systemName: icon).font(.system(size: 11))
                                }
                                Text(mode.displayName).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                        }
                    }
                }

                SettingsGroupLabel(text: "Menu Bar")
                SettingsGroup {
                    SettingsRow(
                        "Menu bar icon",
                        subtitle: "The coffee cup shown in the menu bar.",
                        first: true
                    ) {
                        CoffeeGlyphPicker(selection: appearanceBinding)
                    }
                    SettingsRow("Activate with hot key") {
                        KeyboardShortcuts.Recorder(for: .toggleCaffeine)
                    }
                }

                SettingsGroupLabel(text: "Startup & Visibility")
                SettingsGroup {
                    SettingsRow("Start at login", first: true) {
                        Toggle("", isOn: startAtLoginBinding).labelsHidden()
                    }
                    SettingsRow("Show icon in Dock") {
                        Toggle("", isOn: showInDockBinding).labelsHidden()
                    }
                    SettingsRow("Show instruction message when Open Caffein opens") {
                        Toggle("", isOn: $settings.showInstructionMessage).labelsHidden()
                    }
                }
            }
            .padding(20)
        }
    }

    private func icon(for mode: AppearanceMode) -> String? {
        switch mode {
        case .auto: return nil
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    private var actions: GeneralSettingsActions {
        GeneralSettingsActions(
            settings: settings,
            loginItem: loginItem,
            onDockVisibilityChange: onDockVisibilityChange
        )
    }

    private var appearanceBinding: Binding<MenuBarIconStyle> {
        Binding(get: { settings.iconStyle }, set: { actions.setIconStyle($0) })
    }

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(get: { settings.appearanceMode }, set: { settings.appearanceMode = $0 })
    }

    private var startAtLoginBinding: Binding<Bool> {
        Binding(get: { settings.startAtLogin }, set: { actions.setStartAtLogin($0) })
    }

    private var showInDockBinding: Binding<Bool> {
        Binding(get: { settings.showIconInDock }, set: { actions.setShowInDock($0) })
    }
}
