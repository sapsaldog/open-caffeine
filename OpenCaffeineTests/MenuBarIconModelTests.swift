@testable import OpenCaffeine
import XCTest

final class MenuBarIconModelTests: XCTestCase {
    func testTitleEmptyWhenInactive() {
        XCTAssertEqual(
            MenuBarIconModel.title(isActive: false, showCountdown: true, hideSeconds: false, remaining: 300),
            ""
        )
    }

    func testTitleEmptyWhenCountdownDisabled() {
        XCTAssertEqual(
            MenuBarIconModel.title(isActive: true, showCountdown: false, hideSeconds: false, remaining: 300),
            ""
        )
    }

    func testTitleShowsCountdownWhenActiveAndEnabled() {
        let expected = " " + CountdownFormatter.string(remaining: 300, hideSeconds: false)
        XCTAssertEqual(
            MenuBarIconModel.title(isActive: true, showCountdown: true, hideSeconds: false, remaining: 300),
            expected
        )
    }

    func testTitleOmitsSecondsWhenHidden() {
        XCTAssertEqual(
            MenuBarIconModel.title(isActive: true, showCountdown: true, hideSeconds: true, remaining: 5400),
            " 1:30"
        )
    }

    // MARK: Refresh schedule

    func testNoRefreshWhenTheTitleCannotChange() {
        XCTAssertNil(schedule(isActive: false, showCountdown: true, hideSeconds: false, remaining: 300))
        XCTAssertNil(schedule(isActive: true, showCountdown: false, hideSeconds: false, remaining: 300))
        XCTAssertNil(schedule(isActive: true, showCountdown: true, hideSeconds: false, remaining: nil))
    }

    func testRefreshesEverySecondWhenSecondsShown() {
        XCTAssertEqual(
            schedule(isActive: true, showCountdown: true, hideSeconds: false, remaining: 299.4),
            MenuBarIconModel.RefreshSchedule(delay: 1, interval: 1)
        )
    }

    func testRefreshesOnMinuteBoundariesWhenSecondsHidden() throws {
        let refresh = try XCTUnwrap(schedule(isActive: true, showCountdown: true, hideSeconds: true, remaining: 299.5))
        XCTAssertEqual(refresh.delay, 59.5 + MenuBarIconModel.minuteBoundaryLeeway, accuracy: 0.0001)
        XCTAssertEqual(refresh.interval, 60)
    }

    func testRefreshWaitsAFullMinuteWhenExactlyOnABoundary() throws {
        let refresh = try XCTUnwrap(schedule(isActive: true, showCountdown: true, hideSeconds: true, remaining: 300))
        XCTAssertEqual(refresh.delay, 60 + MenuBarIconModel.minuteBoundaryLeeway, accuracy: 0.0001)
    }

    func testScheduledRefreshesLandOnEachNewMinute() throws {
        let remaining: TimeInterval = 299.5
        let refresh = try XCTUnwrap(
            schedule(isActive: true, showCountdown: true, hideSeconds: true, remaining: remaining)
        )
        XCTAssertEqual(hiddenSecondsTitle(remaining: remaining), " 0:05")
        XCTAssertEqual(hiddenSecondsTitle(remaining: remaining - refresh.delay), " 0:04")
        XCTAssertEqual(hiddenSecondsTitle(remaining: remaining - refresh.delay - refresh.interval), " 0:03")
    }

    private func schedule(
        isActive: Bool,
        showCountdown: Bool,
        hideSeconds: Bool,
        remaining: TimeInterval?
    ) -> MenuBarIconModel.RefreshSchedule? {
        MenuBarIconModel.refreshSchedule(
            isActive: isActive,
            showCountdown: showCountdown,
            hideSeconds: hideSeconds,
            remaining: remaining
        )
    }

    private func hiddenSecondsTitle(remaining: TimeInterval) -> String {
        MenuBarIconModel.title(isActive: true, showCountdown: true, hideSeconds: true, remaining: remaining)
    }
}
