@testable import OpenCaffeine
import XCTest

@MainActor
final class HotKeyServiceTests: XCTestCase {
    private let store = TestDefaults()

    override func tearDown() {
        store.remove()
        super.tearDown()
    }

    func testToggleStartsSessionWhenIdle() {
        let session = CaffeineSession(assertion: MockSleepAssertion())
        let service = HotKeyService(session: session, settings: AppSettings(defaults: store.defaults)) { _ in }
        service.toggle()
        XCTAssertTrue(session.state.isActive)
    }

    func testToggleStopsSessionWhenActive() throws {
        let session = CaffeineSession(assertion: MockSleepAssertion())
        try session.start(.minutes(30))
        let service = HotKeyService(session: session, settings: AppSettings(defaults: store.defaults)) { _ in }
        service.toggle()
        XCTAssertFalse(session.state.isActive)
    }

    func testRegisteredHandlerTogglesSession() {
        var captured: (() -> Void)?
        let session = CaffeineSession(assertion: MockSleepAssertion())
        let service = HotKeyService(session: session, settings: AppSettings(defaults: store.defaults)) { captured = $0 }
        withExtendedLifetime(service) {
            captured?()
            XCTAssertTrue(session.state.isActive)
        }
    }
}
