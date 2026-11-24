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
    /// What the kernel's `SleepDisabled` flag reads.
    private var kernelSleepDisabled: Bool? = false
    private var controller: LidSleepController!

    override func setUp() {
        super.setUp()
        helper = MockSleepDisabler()
        display = MockDisplaySleeper()
        scheduled = []
        kernelSleepDisabled = false
        controller = LidSleepController(
            conditions: { [unowned self] in self.conditions },
            helper: helper,
            display: display,
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

    /// The reviewer's case end to end, through the helper's real rules: a release
    /// fails, the session comes back before the helper retries, and that retry must
    /// not put sleep back (or sleep the Mac) under an active switch.
    func testReenablingAfterAFailedReleaseKeepsSleepBlockedEndToEnd() {
        let power = FakeSleepControl()
        var helperRetries: [() -> Void] = []
        let core = SleepHelperCore(control: power, retryInterval: 5) { _, work in helperRetries.append(work) }
        core.connectionOpened()
        let endToEnd = LidSleepController(
            conditions: { [unowned self] in self.conditions },
            helper: InProcessHelper(core: core),
            display: display,
            sleepDisabledNow: { power.disabled },
            schedule: { [unowned self] delay, work in self.scheduled.append((delay, work)) }
        )
        endToEnd.refresh()
        power.restoreWorks = false
        conditions.sessionActive = false
        endToEnd.refresh()
        XCTAssertEqual(endToEnd.state, .restoreFailed)

        power.restoreWorks = true
        conditions.sessionActive = true
        endToEnd.refresh()
        helperRetries.forEach { $0() }
        runScheduled()
        XCTAssertEqual(endToEnd.state, .active)
        XCTAssertTrue(power.disabled)
        XCTAssertFalse(power.calls.contains("sleepIfLidIsClosed"))
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
            display: display,
            sleepDisabledNow: { false }
        )
        liveController.refresh()
        wait(for: [retried], timeout: 5)
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

    /// Unregistered or refused: trust the kernel's flag, not an assumption.
    func testAHelperThatIsGoneAndPutSleepBackHoldsNothing() {
        controller.refresh()
        conditions.helperApproved = false
        kernelSleepDisabled = false
        controller.helperInvalidated()
        XCTAssertEqual(controller.state, .needsApproval)
        XCTAssertEqual(helper.requests, [true])
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

/// The app's controller wired straight to the helper's rules, as XPC would.
private final class InProcessHelper: SleepDisabling {
    private let core: SleepHelperCore

    init(core: SleepHelperCore) {
        self.core = core
    }

    func setSleepDisabled(_ disabled: Bool, completion: @escaping (Bool) -> Void) {
        completion(core.request(disabled, by: 1))
    }
}
