@testable import OpenCaffein
import XCTest

final class SessionStateTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1000)

    func testProgressIsZeroWhenIdle() {
        XCTAssertEqual(SessionState.idle.progressShown(now: start), 0)
    }

    func testProgressIsFullForActiveForever() {
        let state = SessionState.active(duration: .forever, startedAt: start)
        XCTAssertEqual(state.progressShown(now: start.addingTimeInterval(9999)), 1)
    }

    func testProgressIsFullAtStartOfFiniteSession() {
        let state = SessionState.active(duration: .minutes(10), startedAt: start)
        XCTAssertEqual(state.progressShown(now: start), 1, accuracy: 0.0001)
    }

    func testProgressIsHalfwayThroughFiniteSession() {
        let state = SessionState.active(duration: .minutes(10), startedAt: start)
        XCTAssertEqual(state.progressShown(now: start.addingTimeInterval(300)), 0.5, accuracy: 0.0001)
    }

    func testProgressClampsToZeroPastExpiry() {
        let state = SessionState.active(duration: .minutes(10), startedAt: start)
        XCTAssertEqual(state.progressShown(now: start.addingTimeInterval(700)), 0)
    }

    func testProgressIsFullForZeroLengthCustom() {
        let state = SessionState.active(duration: .custom(seconds: 0), startedAt: start)
        XCTAssertEqual(state.progressShown(now: start), 1)
    }
}
