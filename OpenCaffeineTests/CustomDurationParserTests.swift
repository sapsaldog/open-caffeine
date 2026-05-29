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
}
