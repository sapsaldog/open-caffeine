@testable import OpenCaffeine
import XCTest

/// The app's controller wired to the helper's real rules (`SleepHelperCore`) with a
/// fake `pmset`, to catch the two disagreeing about who holds sleep.
final class LidSleepEndToEndTests: XCTestCase {
    private var conditions = LidSleepConditions(
        enabled: true,
        sessionActive: true,
        helperApproved: true,
        power: PowerStatus(onBattery: false, batteryPercent: 80),
        thermal: .nominal
    )
    private var scheduled: [(delay: TimeInterval, work: () -> Void)] = []

    private func runScheduled() {
        let work = scheduled
        scheduled = []
        work.forEach { $0.work() }
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
            display: MockDisplaySleeper(),
            system: MockSystemSleeper(),
            closedLidShouldSleep: { false },
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
