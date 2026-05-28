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
}
