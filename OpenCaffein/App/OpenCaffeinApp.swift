import SwiftUI

@main
struct OpenCaffeinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesScene(onDockVisibilityChange: { [appDelegate] visible in
                appDelegate.applyDockVisibility(visible)
            })
        }
    }
}
