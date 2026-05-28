import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    let loginItem: LoginItemManager
    let onDockVisibilityChange: (Bool) -> Void

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                HotKeyRecorderRow()
            }

            Section {
                Toggle("Start at login", isOn: startAtLoginBinding)
                Toggle("Show icon in dock", isOn: showInDockBinding)
                Toggle("Show instruction message when Open Caffein opens",
                       isOn: $settings.showInstructionMessage)
            }
        }
        .padding(20)
        .formStyle(.grouped)
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

    private var startAtLoginBinding: Binding<Bool> {
        Binding(get: { settings.startAtLogin }, set: { actions.setStartAtLogin($0) })
    }

    private var showInDockBinding: Binding<Bool> {
        Binding(get: { settings.showIconInDock }, set: { actions.setShowInDock($0) })
    }
}
