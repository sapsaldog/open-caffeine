@testable import OpenCaffeine
import XCTest

final class CountdownFormatterTests: XCTestCase {
    func testZeroFormatsAsMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 0), "0:00")
    }

    func testUnderOneHourUsesMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 59), "0:59")
        XCTAssertEqual(CountdownFormatter.string(remaining: 90), "1:30")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3599), "59:59")
    }

    func testAtOrAboveOneHourUsesHourMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 3600), "1:00:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3661), "1:01:01")
        XCTAssertEqual(CountdownFormatter.string(remaining: 43200), "12:00:00")
    }

    func testNilReturnsInfinity() {
        XCTAssertEqual(CountdownFormatter.string(remaining: nil), "∞")
    }
}
