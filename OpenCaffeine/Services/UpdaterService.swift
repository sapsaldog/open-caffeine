import Sparkle

/// Wraps Sparkle's standard updater so the Updates preferences tab can drive
/// real update checks. Reads `SUFeedURL` / `SUPublicEDKey` from Info.plist.
/// Thin Sparkle shell — excluded from the coverage gate.
@MainActor
final class UpdaterService {
    static let shared = UpdaterService()

    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// User-initiated check — shows Sparkle's standard progress/result window.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }
}
