import AppKit

/// Pure launch-time decisions extracted from `AppDelegate` so they are testable
/// without driving the application lifecycle.
enum AppLaunchLogic {
    static func activationPolicy(forDockVisible visible: Bool) -> NSApplication.ActivationPolicy {
        visible ? .regular : .accessory
    }

    static func shouldShowInstructionMessage(showInstructionMessage: Bool, alreadyShown: Bool) -> Bool {
        showInstructionMessage && !alreadyShown
    }

    /// True when the app was launched only to host the unit tests. Its normal
    /// startup (menu-bar item, global hot key, updater, login item) would then run
    /// against the developer's real Mac and preferences, so `AppDelegate` skips it.
    static func isRunningAsTestHost(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
