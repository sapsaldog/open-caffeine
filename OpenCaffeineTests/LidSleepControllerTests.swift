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
    private var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
    private var controller: LidSleepController!

    override func setUp() {
        super.setUp()
        helper = MockSleepDisabler()
        display = MockDisplaySleeper()
        scheduled = []
        controller = LidSleepController(
            conditions: { [unowned self] in self.conditions },
            helper: helper,
            display: display,
            schedule: { [unowned self] delay, work in self.scheduled.append((delay, work)) }
        )
    }

    private func runScheduled() {
        let work = scheduled
        scheduled = []
        work.forEach { $0.work() }
    }

    // MARK: Following the policy

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

    // MARK: One request at a time

    func testShowsActiveOnlyOnceTheHelperConfirms() {
        helper.defersReplies = true
        controller.refresh()
        XCTAssertEqual(controller.state, .off)
        helper.reply(true)
        XCTAssertEqual(controller.state, .active)
    }

    func testSendsOneRequestAtATime() {
        helper.defersReplies = true
        controller.refresh()
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(helper.requests, [true], "waits for the reply on the wire")
        helper.reply(true)
        XCTAssertEqual(helper.requests, [true, false])
        helper.reply(true)
        XCTAssertEqual(controller.state, .off)
        XCTAssertEqual(helper.pendingReplies, 0)
    }

    /// Two quick toggles whose replies both fail must not leave the controller
    /// thinking sleep is back while macOS still has it disabled.
    func testOverlappingFailuresKeepTrackOfTheRealSetting() {
        controller.refresh()
        helper.defersReplies = true
        conditions.sessionActive = false
        controller.refresh()
        conditions.sessionActive = true
        controller.refresh()
        helper.reply(false)
        XCTAssertEqual(controller.state, .active, "the restore failed, so sleep is still blocked — as wanted now")

        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(helper.requests, [true, false, false], "the change goes out right away")
        helper.reply(true)
        XCTAssertEqual(controller.state, .off)
        runScheduled()
        XCTAssertEqual(helper.requests, [true, false, false], "the old retry has nothing left to do")
    }

    func testALateReplyDoesNotOverrideANewerAnswer() {
        helper.defersReplies = true
        controller.refresh()
        conditions.sessionActive = false
        controller.refresh()
        helper.reply(true)
        XCTAssertEqual(helper.requests, [true, false])
        XCTAssertEqual(controller.state, .off)
        helper.reply(true)
        XCTAssertEqual(controller.state, .off)
        XCTAssertEqual(helper.pendingReplies, 0)
    }

    // MARK: Retrying

    func testRetriesARefusedRequestWithGrowingDelays() {
        helper.accepts = false
        controller.refresh()
        XCTAssertEqual(controller.state, .unavailable)
        XCTAssertEqual(scheduled.map(\.delay), [2])
        runScheduled()
        XCTAssertEqual(scheduled.map(\.delay), [4])
        runScheduled()
        XCTAssertEqual(scheduled.map(\.delay), [8])
        helper.accepts = true
        runScheduled()
        XCTAssertEqual(controller.state, .active)
        XCTAssertEqual(helper.requests, [true, true, true, true])
        XCTAssertTrue(scheduled.isEmpty)
    }

    func testRetryDelayStopsGrowingAtAMinute() {
        helper.accepts = false
        controller.refresh()
        for _ in 0..<10 { runScheduled() }
        XCTAssertEqual(scheduled.map(\.delay), [60])
    }

    /// "Will retry" has to mean it: putting sleep back is retried on its own.
    func testRetriesPuttingSleepBackAndSaysSoMeanwhile() {
        controller.refresh()
        helper.accepts = false
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(controller.state, .restoreFailed)
        helper.accepts = true
        runScheduled()
        XCTAssertEqual(helper.requests, [true, false, false])
        XCTAssertEqual(controller.state, .off)
    }

    /// The live scheduler: the retry really comes, on the main queue.
    func testByDefaultRetriesOnTheMainQueue() {
        let retried = expectation(description: "retried")
        helper.accepts = false
        helper.onRequest = { [unowned self] in
            guard helper.requests.count == 2 else { return }
            XCTAssertTrue(Thread.isMainThread)
            retried.fulfill()
        }
        let liveController = LidSleepController(
            conditions: { [unowned self] in self.conditions },
            helper: helper,
            display: display
        )
        liveController.refresh()
        wait(for: [retried], timeout: 5)
    }

    func testDroppingTheIdeaCancelsTheRetry() {
        helper.accepts = false
        controller.refresh()
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(controller.state, .off, "sleep was never blocked")
        runScheduled()
        XCTAssertEqual(helper.requests, [true])
    }

    // MARK: Helper restarts

    /// The helper crashed and launchd restarted it (it put sleep back while recovering).
    func testReappliesTheHoldAfterTheHelperRestarts() {
        controller.refresh()
        controller.helperInterrupted()
        XCTAssertEqual(helper.requests, [true, true])
        XCTAssertEqual(controller.state, .active)
    }

    func testMakesSureSleepIsBackAfterARestartWhileOff() {
        controller.refresh()
        conditions.sessionActive = false
        controller.refresh()
        controller.helperInterrupted()
        XCTAssertEqual(helper.requests, [true, false, false])
    }

    /// Unregistered or refused: the helper put sleep back on its way out.
    func testAHelperThatIsGoneHoldsNothing() {
        controller.refresh()
        conditions.helperApproved = false
        controller.helperInvalidated()
        XCTAssertEqual(controller.state, .needsApproval)
        XCTAssertEqual(helper.requests, [true])
    }

    // MARK: Closing the lid

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
}
