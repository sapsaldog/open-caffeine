@testable import OpenCaffeine
import XCTest

@MainActor
final class HotKeyServiceTests: XCTestCase {
    func testToggleStartsSessionWhenIdle() {
        let session = CaffeineSession(assertion: MockSleepAssertion())
        let service = HotKeyService(session: session, settings: AppSettings()) { _ in }
        service.toggle()
        XCTAssertTrue(session.state.isActive)
    }

    func testToggleStopsSessionWhenActive() throws {
        let session = CaffeineSession(assertion: MockSleepAssertion())
        try session.start(.minutes(30))
        let service = HotKeyService(session: session, settings: AppSettings()) { _ in }
        service.toggle()
        XCTAssertFalse(session.state.isActive)
    }

    func testRegisteredHandlerTogglesSession() {
        var captured: (() -> Void)?
        let session = CaffeineSession(assertion: MockSleepAssertion())
        let service = HotKeyService(session: session, settings: AppSettings()) { captured = $0 }
        withExtendedLifetime(service) {
            captured?()
            XCTAssertTrue(session.state.isActive)
        }
    }
}
