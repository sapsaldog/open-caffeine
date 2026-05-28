import Combine
@testable import OpenCaffein
import XCTest

final class CaffeineSessionTests: XCTestCase {
    private var assertion: MockSleepAssertion!
    private var session: CaffeineSession!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        assertion = MockSleepAssertion()
        session = CaffeineSession(assertion: assertion)
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testStartsIdle() {
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(assertion.acquireCount, 0)
    }

    func testStartAcquiresAssertion() throws {
        try session.start(.minutes(30))
        XCTAssertTrue(session.state.isActive)
        XCTAssertEqual(assertion.acquireCount, 1)
    }

    func testStopReleasesAssertion() throws {
        try session.start(.minutes(30))
        session.stop()
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(assertion.releaseCount, 1)
    }

    func testDuplicateStartReleasesPriorAssertion() throws {
        try session.start(.minutes(10))
        try session.start(.minutes(20))
        XCTAssertEqual(assertion.acquireCount, 2)
        XCTAssertEqual(assertion.releaseCount, 1)
    }

    func testAcquireFailureLeavesSessionIdle() {
        assertion.acquireError = NSError(domain: "test", code: 1)
        XCTAssertThrowsError(try session.start(.minutes(5)))
        XCTAssertEqual(session.state, .idle)
    }

    func testForeverHasNilRemaining() throws {
        try session.start(.forever)
        XCTAssertNil(session.state.remaining())
    }

    func testFiniteRemainingDecreases() throws {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1000))
        session = CaffeineSession(assertion: assertion, clock: clock.now)
        try session.start(.minutes(5))
        clock.currentDate = Date(timeIntervalSince1970: 1060) // +60s
        XCTAssertEqual(session.state.remaining(now: clock.now()), 240)
    }

    func testStatePublishedOnStart() throws {
        let exp = expectation(description: "state change")
        session.$state
            .dropFirst()
            .sink { state in
                if state.isActive { exp.fulfill() }
            }
            .store(in: &cancellables)
        try session.start(.minutes(5))
        wait(for: [exp], timeout: 1.0)
    }

    func testExpiryStopsSessionAndReleasesAssertion() throws {
        let exp = expectation(description: "auto-stop on expiry")
        session.$state
            .dropFirst()
            .sink { state in if state == .idle { exp.fulfill() } }
            .store(in: &cancellables)
        try session.start(.custom(seconds: 0.05))
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(assertion.releaseCount, 1)
    }

    func testDeinitReleasesActiveAssertion() throws {
        let local = MockSleepAssertion()
        do {
            let transient = CaffeineSession(assertion: local)
            try transient.start(.minutes(30))
            XCTAssertEqual(local.acquireCount, 1)
        }
        XCTAssertEqual(local.releaseCount, 1)
    }
}

/// Test helper: mutable clock you can advance by hand.
final class MutableClock {
    var currentDate: Date
    init(now: Date) { self.currentDate = now }
    func now() -> Date { currentDate }
}
