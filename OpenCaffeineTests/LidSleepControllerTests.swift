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
    /// What `Clamshell` would say: lid shut and macOS would sleep for it.
    private var lidClosedAndShouldSleep = false
    private var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
    /// What the kernel's `SleepDisabled` flag reads.
    private var kernelSleepDisabled: Bool? = false
    private var controller: LidSleepController!

    override func setUp() {
        super.setUp()
        helper = MockSleepDisabler()
        display = MockDisplaySleeper()
        system = MockSystemSleeper()
        lidClosedAndShouldSleep = false
        scheduled = []
        kernelSleepDisabled = false
        controller = LidSleepController(
            conditions: { [unowned self] in self.conditions },
            helper: helper,
            display: display,
            system: system,
            closedLidShouldSleep: { [unowned self] in self.lidClosedAndShouldSleep },
            sleepDisabledNow: { [unowned self] in self.kernelSleepDisabled },
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

    /// A failed release says nothing reliable about what this app still holds (the
    /// helper may already have let go), so re-enabling asks for the hold again.
    func testAFailedReleaseIsNotTakenAsAHoldStillInPlace() {
        controller.refresh()
        helper.defersReplies = true
        conditions.sessionActive = false
        controller.refresh()
        conditions.sessionActive = true
        controller.refresh()
        helper.reply(false)
        XCTAssertEqual(helper.requests, [true, false, true], "the hold is asked for again, right away")
        helper.reply(true)
        XCTAssertEqual(controller.state, .active)

        conditions.sessionActive = false
        controller.refresh()
        helper.reply(true)
        XCTAssertEqual(controller.state, .off)
        runScheduled()
        XCTAssertEqual(helper.requests, [true, false, true, false], "no stale retry left behind")
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
        kernelSleepDisabled = true
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
            display: display,
            system: system,
            closedLidShouldSleep: { false },
            sleepDisabledNow: { false }
        )
        liveController.refresh()
        wait(for: [retried], timeout: 5)
    }

    /// The warning is about sleep still being disabled; the kernel has the last word.
    func testNoWarningOnceTheKernelSaysSleepIsBack() {
        controller.refresh()
        helper.accepts = false
        kernelSleepDisabled = false
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(controller.state, .off)
    }

    func testDroppingTheIdeaCancelsTheRetry() {
        helper.accepts = false
        controller.refresh()
        helper.accepts = true
        conditions.sessionActive = false
        controller.refresh()
        XCTAssertEqual(controller.state, .off)
        runScheduled()
        XCTAssertEqual(helper.requests, [true, false], "one release to be sure, then nothing more")
    }
}

// MARK: - Helper restarts and the lid

extension LidSleepControllerTests {

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

    /// Unregistered or refused: what this app holds is unknown now; the kernel's
    /// flag only decides whether to warn.
    func testAHelperThatIsGoneAndPutSleepBackHoldsNothing() {
        controller.refresh()
        conditions.helperApproved = false
        kernelSleepDisabled = false
        helper.accepts = false
        controller.helperInvalidated()
        XCTAssertEqual(controller.state, .needsApproval, "no warning: sleep is back")
        XCTAssertEqual(helper.requests, [true, false])
    }

    /// Approval came back before the old connection's invalidation arrived: the
    /// kernel still says disabled, but the hold must come from the new connection.
    func testAskedAgainForTheHoldWhenStillWantedAfterTheHelperIsGone() {
        controller.refresh()
        kernelSleepDisabled = true
        controller.helperInvalidated()
        XCTAssertEqual(helper.requests, [true, true])
        XCTAssertEqual(controller.state, .active)
    }

    /// The helper went away while the app runs (approval revoked) with the lid shut:
    /// nothing may re-check the lid, so the app puts the Mac to sleep.
    func testSleepsAShutLidWhenTheHelperGoesAwayWhileTheAppRuns() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        kernelSleepDisabled = false
        controller.helperInvalidated()
        XCTAssertEqual(system.sleepCount, 1)
    }

    /// Quitting or a system shutdown also closes the connection: no sleep then.
    func testDoesNotSleepTheMacWhileTheAppIsQuitting() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        controller.appWillTerminate()
        controller.helperInvalidated()
        XCTAssertEqual(system.sleepCount, 0)
    }

    func testDoesNotAskForSleepThatCannotHappen() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        kernelSleepDisabled = true
        controller.helperInvalidated()
        XCTAssertEqual(system.sleepCount, 0)
    }

    func testLeavesAnOpenLidAwakeWhenTheHelperGoesAway() {
        controller.refresh()
        controller.helperInvalidated()
        XCTAssertEqual(system.sleepCount, 0)
    }

    func testSurvivesASystemSleepFailure() {
        controller.refresh()
        lidClosedAndShouldSleep = true
        system.error = NSError(domain: "test", code: 4)
        controller.helperInvalidated()
        XCTAssertEqual(system.sleepCount, 1)
    }

    func testAHelperThatIsGoneButLeftSleepDisabledIsShown() {
        controller.refresh()
        conditions.helperApproved = false
        kernelSleepDisabled = true
        helper.accepts = false
        controller.helperInvalidated()
        XCTAssertEqual(controller.state, .restoreFailed)
        XCTAssertEqual(helper.requests, [true, false])
    }

    func testAnUnreadableFlagAfterTheHelperIsGoneIsTreatedAsUnknown() {
        controller.refresh()
        conditions.helperApproved = false
        kernelSleepDisabled = nil
        controller.helperInvalidated()
        XCTAssertEqual(helper.requests, [true, false], "makes sure with a release")
        XCTAssertEqual(controller.state, .needsApproval)
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
