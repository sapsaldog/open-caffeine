import IOKit.ps
@testable import OpenCaffein
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
}
