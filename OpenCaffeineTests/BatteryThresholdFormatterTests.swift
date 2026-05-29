@testable import OpenCaffeine
import XCTest

final class BatteryThresholdFormatterTests: XCTestCase {
    func testNoBatteryShowsDash() {
        XCTAssertEqual(BatteryThresholdFormatter.label(hasBattery: false, percent: 30), "—")
    }

    func testZeroPercentShowsDisabled() {
        XCTAssertEqual(BatteryThresholdFormatter.label(hasBattery: true, percent: 0), "Disabled")
    }

    func testPositivePercentShowsValue() {
        XCTAssertEqual(BatteryThresholdFormatter.label(hasBattery: true, percent: 20), "20%")
    }
}
