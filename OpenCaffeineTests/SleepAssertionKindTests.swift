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

    func testDisplayAndSystemUsesDisplayAssertionType() {
        XCTAssertEqual(
            SleepAssertionKind.displayAndSystem.ioKitAssertionType,
            kIOPMAssertPreventUserIdleDisplaySleep
        )
    }

    func testSystemOnlyUsesSystemAssertionType() {
        XCTAssertEqual(
            SleepAssertionKind.systemOnly.ioKitAssertionType,
            kIOPMAssertPreventUserIdleSystemSleep
        )
    }
}
