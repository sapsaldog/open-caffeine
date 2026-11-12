@testable import OpenCaffeine
import XCTest

@MainActor
final class PanelClockTests: XCTestCase {
    private final class FakeDate {
        var value = Date(timeIntervalSince1970: 1000)
        func advance(by seconds: TimeInterval) { value = value.addingTimeInterval(seconds) }
    }

    private let date = FakeDate()

    private func makeClock(interval: TimeInterval = 60) -> PanelClock {
        PanelClock(interval: interval) { [date] in date.value }
    }

    private func spinRunLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testDefaultsToTheSystemClock() {
        let before = Date()
        let clock = PanelClock()
        XCTAssertGreaterThanOrEqual(clock.now, before)
        XCTAssertLessThanOrEqual(clock.now, Date())
        XCTAssertFalse(clock.isRunning)
    }

    func testIsStoppedUntilStarted() {
        let clock = makeClock()
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.now, date.value)
    }

    func testStartRefreshesNowImmediately() {
        let clock = makeClock()
        date.advance(by: 3600)  // the panel was hidden for an hour
        clock.start()
        defer { clock.stop() }
        XCTAssertTrue(clock.isRunning)
        XCTAssertEqual(clock.now, date.value)
    }

    func testTickRefreshesNow() {
        let clock = makeClock()
        date.advance(by: 1)
        clock.tick()
        XCTAssertEqual(clock.now, date.value)
    }

    func testTicksWhileRunningAndNotAfterStop() {
        let clock = makeClock(interval: 0.02)
        clock.start()
        date.advance(by: 1)
        spinRunLoop(for: 0.2)
        XCTAssertEqual(clock.now, date.value, "should tick while the panel is open")

        clock.stop()
        XCTAssertFalse(clock.isRunning)
        let frozen = clock.now
        date.advance(by: 1)
        spinRunLoop(for: 0.2)
        XCTAssertEqual(clock.now, frozen, "must not tick while the panel is hidden")
    }

    func testStartingTwiceLeavesNoTimerRunningAfterStop() {
        let clock = makeClock(interval: 0.02)
        clock.start()
        clock.start()
        clock.stop()
        let frozen = clock.now
        date.advance(by: 1)
        spinRunLoop(for: 0.2)
        XCTAssertEqual(clock.now, frozen)
    }
}
