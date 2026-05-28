import Foundation

@MainActor
final class HotKeyService {
    private let session: CaffeineSession
    private let settings: AppSettings

    init(
        session: CaffeineSession,
        settings: AppSettings,
        register: (@escaping () -> Void) -> Void = registerToggleHotKey
    ) {
        self.session = session
        self.settings = settings
        register { [weak self] in self?.toggle() }
    }

    func toggle() {
        if session.state.isActive {
            session.stop()
        } else {
            try? session.start(settings.defaultDuration)
        }
    }
}
