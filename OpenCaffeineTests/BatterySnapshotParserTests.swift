import IOKit.ps
@testable import OpenCaffeine
import XCTest

final class BatterySnapshotParserTests: XCTestCase {
    func testReturnsRoundedPercentForValidSource() {
        let descriptions: [[String: AnyObject]] = [[
            kIOPSMaxCapacityKey: 200 as AnyObject,
            kIOPSCurrentCapacityKey: 50 as AnyObject
        ]]
        let result = BatterySnapshotParser.parse(descriptions)
        XCTAssertTrue(result.hasBattery)
        XCTAssertEqual(result.percent, 25)
    }

    func testEmptyListReturnsNoBattery() {
        let result = BatterySnapshotParser.parse([])
        XCTAssertFalse(result.hasBattery)
        XCTAssertEqual(result.percent, 0)
    }

    func testSkipsSourcesWithoutValidCapacity() {
        let descriptions: [[String: AnyObject]] = [
            ["unrelated": 1 as AnyObject],
            [kIOPSMaxCapacityKey: 0 as AnyObject, kIOPSCurrentCapacityKey: 0 as AnyObject]
        ]
        XCTAssertFalse(BatterySnapshotParser.parse(descriptions).hasBattery)
    }

    private let halfFull: [[String: AnyObject]] = [[
        kIOPSMaxCapacityKey: 100 as AnyObject,
        kIOPSCurrentCapacityKey: 15 as AnyObject
    ]]

    func testPowerStatusOnBatteryCarriesTheCharge() {
        XCTAssertEqual(
            BatterySnapshotParser.powerStatus(providingType: kIOPSBatteryPowerValue, descriptions: halfFull),
            PowerStatus(onBattery: true, batteryPercent: 15)
        )
    }

    /// Plugged in, a low charge is climbing — not a reason to let the Mac sleep.
    func testPowerStatusOnPowerAdapterIsNotOnBattery() {
        XCTAssertEqual(
            BatterySnapshotParser.powerStatus(providingType: kIOPSACPowerValue, descriptions: halfFull),
            PowerStatus(onBattery: false, batteryPercent: 15)
        )
    }

    func testPowerStatusWithUnknownSourceIsNotOnBattery() {
        XCTAssertEqual(
            BatterySnapshotParser.powerStatus(providingType: nil, descriptions: []),
            PowerStatus(onBattery: false, batteryPercent: 0)
        )
    }
}
