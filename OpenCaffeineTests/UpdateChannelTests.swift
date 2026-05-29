@testable import OpenCaffeine
import XCTest

final class UpdateChannelTests: XCTestCase {
    func testRawValuesRoundTrip() {
        XCTAssertEqual(UpdateChannel(rawValue: "stable"), .stable)
        XCTAssertEqual(UpdateChannel(rawValue: "beta"), .beta)
        XCTAssertNil(UpdateChannel(rawValue: "nope"))
    }

    func testDisplayNames() {
        XCTAssertEqual(UpdateChannel.stable.displayName, "Stable")
        XCTAssertEqual(UpdateChannel.beta.displayName, "Beta")
    }

    func testIdMatchesRawValue() {
        XCTAssertEqual(UpdateChannel.beta.id, "beta")
    }

    func testAllCasesOrder() {
        XCTAssertEqual(UpdateChannel.allCases, [.stable, .beta])
    }
}
