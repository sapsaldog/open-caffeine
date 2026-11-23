import IOKit.pwr_mgt
@testable import OpenCaffeine
import XCTest

final class SleepAssertionKindTests: XCTestCase {
    func testKeepDisplayAwakeMapsToDisplayAndSystem() {
        XCTAssertEqual(SleepAssertionKind(keepDisplayAwake: true), .displayAndSystem)
    }

    func testAllowDisplaySleepMapsToSystemOnly() {
        XCTAssertEqual(SleepAssertionKind(keepDisplayAwake: false), .systemOnly)
    }

    func testDisplayAndSystemHoldsDisplayAndSystemAssertionTypes() {
        XCTAssertEqual(
            SleepAssertionKind.displayAndSystem.ioKitAssertionTypes,
            [kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertPreventUserIdleSystemSleep]
        )
    }

    func testSystemOnlyHoldsOnlySystemAssertionType() {
        XCTAssertEqual(
            SleepAssertionKind.systemOnly.ioKitAssertionTypes,
            [kIOPMAssertPreventUserIdleSystemSleep]
        )
    }
}
