@testable import OpenCaffeine
import XCTest

final class LidSleepPolicyTests: XCTestCase {
    /// Everything allows it: switch on, session running, helper approved, cool, plugged in.
    private let ready = LidSleepConditions(
        enabled: true,
        sessionActive: true,
        helperApproved: true,
        power: PowerStatus(onBattery: false, batteryPercent: 80),
        thermal: .nominal
    )

    private func state(_ change: (inout LidSleepConditions) -> Void = { _ in }) -> LidSleepState {
        var conditions = ready
        change(&conditions)
        return LidSleepPolicy.state(for: conditions)
    }

    func testBlocksLidSleepWhenEverythingAllowsIt() {
        XCTAssertEqual(state(), .active)
    }

    func testOffWhenTheSwitchIsOff() {
        XCTAssertEqual(state { $0.enabled = false }, .off)
    }

    /// Only a running session keeps the Mac awake; the lid follows the same rule.
    func testOffWhenNoSessionIsRunning() {
        XCTAssertEqual(state { $0.sessionActive = false }, .off)
    }

    func testNeedsApprovalUntilTheHelperIsAllowed() {
        XCTAssertEqual(state { $0.helperApproved = false }, .needsApproval)
    }

    /// A closed lid traps heat; once macOS reports serious heat, let the Mac sleep.
    func testPausesWhenTheMacIsTooHot() {
        XCTAssertEqual(state { $0.thermal = .serious }, .paused(.tooHot))
        XCTAssertEqual(state { $0.thermal = .critical }, .paused(.tooHot))
    }

    func testFairThermalStateIsFine() {
        XCTAssertEqual(state { $0.thermal = .fair }, .active)
    }

    func testPausesOnBatteryBelowTwentyPercent() {
        XCTAssertEqual(state { $0.power = PowerStatus(onBattery: true, batteryPercent: 19) }, .paused(.lowBattery))
    }

    func testTwentyPercentOnBatteryIsStillFine() {
        XCTAssertEqual(state { $0.power = PowerStatus(onBattery: true, batteryPercent: 20) }, .active)
    }

    /// Plugged in, the charge is climbing: closing the lid shouldn't stop the work.
    func testLowChargeOnThePowerAdapterIsFine() {
        XCTAssertEqual(state { $0.power = PowerStatus(onBattery: false, batteryPercent: 5) }, .active)
    }

    // MARK: Caption under the switch

    func testNoCaptionWhileOffOrWorking() {
        XCTAssertNil(LidSleepState.off.caption)
        XCTAssertNil(LidSleepState.active.caption)
    }

    func testApprovalCaptionIsAHintNotAWarning() {
        XCTAssertEqual(
            LidSleepState.needsApproval.caption,
            "Allow Open Caffeine in System Settings to finish setting this up."
        )
        XCTAssertFalse(LidSleepState.needsApproval.captionIsWarning)
    }

    func testPausedAndFailedCaptionsWarnThatTheLidWillSleepTheMac() {
        XCTAssertEqual(
            LidSleepState.paused(.lowBattery).caption,
            "Paused — battery is below 20%. Closing the lid will put your Mac to sleep."
        )
        XCTAssertEqual(
            LidSleepState.paused(.tooHot).caption,
            "Paused — your Mac is too hot. Closing the lid will put your Mac to sleep."
        )
        XCTAssertEqual(LidSleepState.unavailable.caption, "Couldn't keep your Mac awake with the lid closed.")
        XCTAssertEqual(LidSleepState.restoreFailed.caption, "Couldn't let your Mac sleep again yet — retrying.")
        XCTAssertTrue(LidSleepState.restoreFailed.captionIsWarning)
        XCTAssertTrue(LidSleepState.paused(.lowBattery).captionIsWarning)
        XCTAssertTrue(LidSleepState.paused(.tooHot).captionIsWarning)
        XCTAssertTrue(LidSleepState.unavailable.captionIsWarning)
    }
}
