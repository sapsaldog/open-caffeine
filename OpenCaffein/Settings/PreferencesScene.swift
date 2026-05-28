import SwiftUI

struct PreferencesScene: View {
    @StateObject private var settings = AppSettings.shared
    private let loginItem = LoginItemManager()
    let onDockVisibilityChange: (Bool) -> Void

    var body: some View {
        TabView {
            GeneralSettingsView(
                settings: settings,
                loginItem: loginItem,
                onDockVisibilityChange: onDockVisibilityChange
            )
            .tabItem { Label("General", systemImage: "gear") }

            DurationSettingsView(settings: settings)
                .tabItem { Label("Duration & Battery", systemImage: "clock") }
        }
        .frame(width: 520, height: 360)
    }
}
