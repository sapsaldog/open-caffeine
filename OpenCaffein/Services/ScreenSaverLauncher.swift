import AppKit
import os.log

enum ScreenSaverLauncher {
    private static let log = Logger(subsystem: "com.opencaffein", category: "screensaver")

    @MainActor
    static func launch() {
        let url = URL(
            fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"
        )
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                log.error("ScreenSaver launch failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
