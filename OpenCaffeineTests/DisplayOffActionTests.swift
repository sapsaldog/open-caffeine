@testable import OpenCaffeine
import XCTest

final class DisplayOffActionTests: XCTestCase {
    private var assertion: MockSleepAssertion!
    private var session: CaffeineSession!
    private var display: MockDisplaySleeper!
    private var pending: [(delay: TimeInterval, work: () -> Void)] = []

    override func setUp() {
        super.setUp()
        assertion = MockSleepAssertion()
        session = CaffeineSession(assertion: assertion)
        display = MockDisplaySleeper()
        pending = []
    }

    override func tearDown() {
        session.stop()
        super.tearDown()
    }

    /// An action whose delayed display-sleep is captured instead of waited for.
    private func makeAction() -> DisplayOffAction {
        DisplayOffAction(session: session, display: display) { [unowned self] delay, work in
            self.pending.append((delay, work))
        }
    }

    private func runPending() {
        pending.forEach { $0.work() }
        pending = []
    }

    func testIdleStartsASessionThenSleepsTheDisplay() {
        makeAction().perform(startingWith: .hours(2))

        guard case .active(let duration, _) = session.state else { return XCTFail("expected an active session") }
        XCTAssertEqual(duration, .hours(2))
        XCTAssertEqual(display.sleepCount, 0, "the display sleeps only once the delay has passed")
        runPending()
        XCTAssertEqual(display.sleepCount, 1)
    }

    func testRunningSessionKeepsGoingUntouched() throws {
        try session.start(.minutes(30))
        let running = session.state

        makeAction().perform(startingWith: .hours(2))

        XCTAssertEqual(session.state, running, "must not restart or change the running session")
        XCTAssertEqual(assertion.acquireCount, 1)
        runPending()
        XCTAssertEqual(display.sleepCount, 1)
    }

    /// Without a session the Mac could fall asleep once the screen is dark and
    /// stop the user's work, so a failed start leaves the display on.
    func testLeavesTheDisplayOnWhenNoSessionCanStart() {
        assertion.acquireError = NSError(domain: "test", code: 1)

        makeAction().perform(startingWith: .forever)

        XCTAssertEqual(session.state, .idle)
        runPending()
        XCTAssertEqual(display.sleepCount, 0)
    }

    /// The session ended during the delay (timer, low battery, hot key): with
    /// nothing keeping the Mac awake, leave the display on rather than blank it.
    func testLeavesTheDisplayOnIfTheSessionEndsDuringTheDelay() {
        makeAction().perform(startingWith: .hours(2))
        session.stop()
        runPending()
        XCTAssertEqual(display.sleepCount, 0)
        XCTAssertEqual(session.state, .idle, "a stopped session stays stopped")
    }

    func testSessionKeepsRunningWhenTheDisplayCannotSleep() {
        display.error = NSError(domain: "test", code: 2)

        makeAction().perform(startingWith: .forever)
        runPending()

        XCTAssertEqual(display.sleepCount, 1)
        XCTAssertTrue(session.state.isActive)
    }

    func testWaitsASecondSoTheClickingHandDoesNotWakeTheDisplay() {
        makeAction().perform(startingWith: .forever)
        XCTAssertEqual(pending.map(\.delay), [1])
    }

    func testByDefaultSleepsTheDisplayOnTheMainQueueAfterTheDelay() {
        let slept = expectation(description: "display slept")
        display.onSleep = {
            XCTAssertTrue(Thread.isMainThread)
            slept.fulfill()
        }

        DisplayOffAction(session: session, display: display, delay: 0.05).perform(startingWith: .forever)

        XCTAssertEqual(display.sleepCount, 0, "must not sleep before the delay")
        wait(for: [slept], timeout: 2)
    }
}
