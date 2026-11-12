@testable import OpenCaffeine
import XCTest

final class CountdownFormatterTests: XCTestCase {
    func testZeroFormatsAsMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 0, hideSeconds: false), "0:00")
    }

    func testUnderOneHourUsesMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 59, hideSeconds: false), "0:59")
        XCTAssertEqual(CountdownFormatter.string(remaining: 90, hideSeconds: false), "1:30")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3599, hideSeconds: false), "59:59")
    }

    func testAtOrAboveOneHourUsesHourMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 3600, hideSeconds: false), "1:00:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3661, hideSeconds: false), "1:01:01")
        XCTAssertEqual(CountdownFormatter.string(remaining: 43200, hideSeconds: false), "12:00:00")
    }

    func testNilReturnsInfinity() {
        XCTAssertEqual(CountdownFormatter.string(remaining: nil, hideSeconds: false), "∞")
        XCTAssertEqual(CountdownFormatter.string(remaining: nil, hideSeconds: true), "∞")
    }

    func testHideSecondsUsesHourMin() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 0, hideSeconds: true), "0:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: 120, hideSeconds: true), "0:02")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3600, hideSeconds: true), "1:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: 5400, hideSeconds: true), "1:30")
        XCTAssertEqual(CountdownFormatter.string(remaining: 43200, hideSeconds: true), "12:00")
    }

    func testHideSecondsRoundsMinutesUp() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 1, hideSeconds: true), "0:01")
        XCTAssertEqual(CountdownFormatter.string(remaining: 61, hideSeconds: true), "0:02")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3599, hideSeconds: true), "1:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3661, hideSeconds: true), "1:02")
    }

    func testHideSecondsRoundsRawIntervalUp() {
        // Rounds the raw interval up once, so under half a second left is not "0:00".
        XCTAssertEqual(CountdownFormatter.string(remaining: 0.3, hideSeconds: true), "0:01")
        XCTAssertEqual(CountdownFormatter.string(remaining: 60.3, hideSeconds: true), "0:02")
    }

    func testHugeHourCountsAreNotTruncated() {
        // "%d" reads 32 bits, so hour counts past Int32.max used to print negative.
        let remaining: TimeInterval = 3_000_000_000 * 3600
        XCTAssertEqual(CountdownFormatter.string(remaining: remaining, hideSeconds: false), "3000000000:00:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: remaining, hideSeconds: true), "3000000000:00")
    }

    func testNegativeRemainingClampsToZero() {
        XCTAssertEqual(CountdownFormatter.string(remaining: -90, hideSeconds: false), "0:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: -120, hideSeconds: true), "0:00")
    }
}
