@testable import OpenCaffeine
import XCTest

final class LidSleepControllerTests: XCTestCase {
    private var conditions = LidSleepConditions(
        enabled: true,
        sessionActive: true,
        helperApproved: true,
        power: PowerStatus(onBattery: false, batteryPercent: 80),
        thermal: .nominal
    )
    private var helper: MockSleepDisabler!
    private var display: MockDisplaySleeper!
    private var system: MockSystemSleeper!
    /// What `Clamshell` would say: lid closed and macOS would sleep for it.
    private var lidClosedAndShouldSleep = false
    private var controller: LidSleepController!

    override func setUp() {
        super.setUp()
        helper = MockSleepDisabler()
        display = MockDisplaySleeper()
        system = MockSystemSleeper()
        controller = LidSleepController(
            conditions: { [unowned self] in self.conditions },
            helper: helper,
            display: display,
            system: system,
            closedLidShouldSleep: { [unowned self] in self.lidClosedAndShouldSleep }
        )
    }

    func testBlocksLidSleepWhenThePolicyAllowsIt() {
        controller.refresh()
        XCTAssertEqual(controller.state, .active)
        XCTAssertEqual(helper.requests, [true])
    }

    func testAsksTheHelperOnlyWhenTheAnswerChanges() {
        controller.refresh()
        controller.refresh()
        XCTAssertEqual(helper.requests, [true])
    }

    func testPutsSleepBackWhenTheSessionEnds() {
        controller.refresh()
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(controller.state, .off)
        XCTAssertEqual(helper.requests, [true, false])
    }

    func testPutsSleepBackWhenASafetyRuleKicksIn() {
        controller.refresh()
        conditions.thermal = .serious
        controller.refresh()
        XCTAssertEqual(controller.state, .paused(.tooHot))
        XCTAssertEqual(helper.requests, [true, false])
    }

    func testLeavesMacOSAloneWhenSleepWasNeverBlocked() {
        conditions.enabled = false
        controller.refresh()
        conditions.helperApproved = false
        conditions.enabled = true
        controller.refresh()
        XCTAssertEqual(controller.state, .needsApproval)
        XCTAssertEqual(helper.requests, [])
    }

    /// A refusal must show, not leave the switch looking like it works.
    func testReportsUnavailableWhenTheHelperRefuses() {
        helper.accepts = false
        controller.refresh()
        XCTAssertEqual(controller.state, .unavailable)
    }

    func testTriesAgainAfterARefusal() {
        helper.accepts = false
        controller.refresh()
        helper.accepts = true
        controller.refresh()
        XCTAssertEqual(controller.state, .active)
        XCTAssertEqual(helper.requests, [true, true])
    }

    func testTriesAgainWhenPuttingSleepBackFailed() {
        controller.refresh()
        helper.accepts = false
        conditions.sessionActive = false
        controller.refresh()
        helper.accepts = true
        controller.refresh()
        XCTAssertEqual(helper.requests, [true, false, false])
        XCTAssertEqual(controller.state, .off)
    }

    /// With nothing else lit, the built-in display goes dark instead of glowing under the lid.
    func testClosingTheLidTurnsTheDisplayOffWhileActive() {
        controller.refresh()
        controller.lidDidClose(externalDisplayCount: 0)
        XCTAssertEqual(display.sleepCount, 1)
    }

    /// `displaysleepnow` would blank an external monitor too (closed-display setups).
    func testClosingTheLidLeavesExternalDisplaysOn() {
        controller.refresh()
        controller.lidDidClose(externalDisplayCount: 1)
        XCTAssertEqual(display.sleepCount, 0)
    }

    func testClosingTheLidDoesNothingWhenLidModeIsOff() {
        conditions.enabled = false
        controller.refresh()
        controller.lidDidClose(externalDisplayCount: 0)
        XCTAssertEqual(display.sleepCount, 0)
    }

    func testClosingTheLidSurvivesADisplaySleepFailure() {
        display.error = NSError(domain: "test", code: 1)
        controller.refresh()
        controller.lidDidClose(externalDisplayCount: 0)
        XCTAssertEqual(display.sleepCount, 1)
        XCTAssertEqual(controller.state, .active)
    }

    func testRestoreSleepPutsSleepBackWhenItWasBlocked() {
        controller.refresh()
        controller.restoreSleep()
        XCTAssertEqual(helper.requests, [true, false])
    }

    func testRestoreSleepLeavesMacOSAloneWhenNothingWasBlocked() {
        controller.restoreSleep()
        XCTAssertEqual(helper.requests, [])
    }

    // MARK: Lid mode ending while the lid is shut

    /// macOS decides about sleep when the lid closes. If lid mode ends later with the
    /// lid still shut (session over, low battery, heat), nothing may re-check it, so
    /// the Mac is put to sleep — after sleep is allowed again, or the request does nothing.
    func testSleepsTheMacWhenLidModeEndsWithTheLidClosed() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        system.onSleep = { XCTAssertEqual(self.helper.requests.last, false, "sleep must be allowed first") }
        conditions.power = PowerStatus(onBattery: true, batteryPercent: 19)
        controller.refresh()
        XCTAssertEqual(helper.requests, [true, false])
        XCTAssertEqual(system.sleepCount, 1)
    }

    func testSleepsTheMacWhenTheSessionEndsWithTheLidClosed() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(system.sleepCount, 1)
    }

    func testLeavesAnOpenLidAwake() {
        controller.refresh()
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(system.sleepCount, 0)
    }

    func testDoesNotSleepWhenSleepCouldNotBeAllowedAgain() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        helper.accepts = false
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(system.sleepCount, 0)
    }

    func testNothingToSleepWhenLidModeNeverBlockedSleep() {
        lidClosedAndShouldSleep = true
        conditions.enabled = false
        controller.refresh()
        XCTAssertEqual(system.sleepCount, 0)
    }

    func testQuittingWithTheLidClosedAlsoSleepsTheMac() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        controller.restoreSleep()
        XCTAssertEqual(system.sleepCount, 1)
    }

    func testSurvivesASystemSleepFailure() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        system.error = NSError(domain: "test", code: 3)
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(system.sleepCount, 1)
        XCTAssertEqual(controller.state, .off)
    }
}
