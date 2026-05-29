@testable import OpenCaffein
import XCTest

final class DurationTests: XCTestCase {
    func testForeverHasNoTimeInterval() {
        XCTAssertNil(CaffeineDuration.forever.timeInterval)
    }

    func testMinutesConvertsToSeconds() {
        XCTAssertEqual(CaffeineDuration.minutes(30).timeInterval, 1800)
        XCTAssertEqual(CaffeineDuration.minutes(5).timeInterval, 300)
    }

    func testHoursConvertsToSeconds() {
        XCTAssertEqual(CaffeineDuration.hours(2).timeInterval, 7200)
    }

    func testCustomSecondsPassThrough() {
        XCTAssertEqual(CaffeineDuration.custom(seconds: 90).timeInterval, 90)
    }

    func testCustomDisplayNameShowsWholeMinutes() {
        XCTAssertEqual(CaffeineDuration.custom(seconds: 90).displayName, "Custom (1 min)")
        XCTAssertEqual(CaffeineDuration.custom(seconds: 600).displayName, "Custom (10 min)")
    }

    func testPresetsHaveStableDisplayNames() {
        XCTAssertEqual(CaffeineDuration.minutes(5).displayName, "5 min")
        XCTAssertEqual(CaffeineDuration.minutes(45).displayName, "45 min")
        XCTAssertEqual(CaffeineDuration.hours(1).displayName, "1 hour")
        XCTAssertEqual(CaffeineDuration.hours(12).displayName, "12 hours")
        XCTAssertEqual(CaffeineDuration.forever.displayName, "Forever")
    }

    func testChipLabels() {
        XCTAssertEqual(CaffeineDuration.forever.chipLabel, "∞")
        XCTAssertEqual(CaffeineDuration.minutes(5).chipLabel, "5m")
        XCTAssertEqual(CaffeineDuration.minutes(45).chipLabel, "45m")
        XCTAssertEqual(CaffeineDuration.hours(1).chipLabel, "1h")
        XCTAssertEqual(CaffeineDuration.hours(12).chipLabel, "12h")
        XCTAssertEqual(CaffeineDuration.custom(seconds: 600).chipLabel, "···")
    }

    func testStandardPresetsListMatchesMenu() {
        let names = CaffeineDuration.standardPresets.map(\.displayName)
        XCTAssertEqual(names, [
            "Forever", "5 min", "10 min", "15 min", "30 min", "45 min",
            "1 hour", "2 hours", "4 hours", "6 hours", "12 hours"
        ])
    }
}
