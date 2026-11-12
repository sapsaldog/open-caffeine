@testable import OpenCaffeine
import XCTest

final class CustomDurationParserTests: XCTestCase {
    func testParsesPositiveMinutes() {
        XCTAssertEqual(CustomDurationParser.parse("60"), .minutes(60))
        XCTAssertEqual(CustomDurationParser.parse("1"), .minutes(1))
    }

    func testRejectsZero() {
        XCTAssertNil(CustomDurationParser.parse("0"))
    }

    func testRejectsNegative() {
        XCTAssertNil(CustomDurationParser.parse("-5"))
    }

    func testRejectsNonNumeric() {
        XCTAssertNil(CustomDurationParser.parse("abc"))
        XCTAssertNil(CustomDurationParser.parse(""))
    }

    func testAcceptsUpToSevenDays() {
        XCTAssertEqual(CustomDurationParser.parse("10080"), .minutes(10_080))
    }

    func testRejectsLongerThanSevenDays() {
        XCTAssertNil(CustomDurationParser.parse("10081"))
    }

    func testRejectsHugeValuesInsteadOfCrashing() {
        // A session this long used to crash the countdown converting to Int.
        XCTAssertNil(CustomDurationParser.parse("999999999999999999"))
        XCTAssertNil(CustomDurationParser.parse("99999999999999999999"))
    }
}
