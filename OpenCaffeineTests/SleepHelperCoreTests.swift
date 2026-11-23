@testable import OpenCaffeine
import XCTest

/// The root helper's rules, exercised with a fake `pmset` and marker file.
final class SleepHelperCoreTests: XCTestCase {
    private var control: FakeSleepControl!
    private var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
    private var core: SleepHelperCore!
    private var idleCalls = 0

    override func setUp() {
        super.setUp()
        control = FakeSleepControl()
        scheduled = []
        idleCalls = 0
        core = SleepHelperCore(control: control, retryInterval: 5) { [unowned self] delay, work in
            self.scheduled.append((delay, work))
        }
        core.onIdle = { [unowned self] in self.idleCalls += 1 }
    }

    private func runScheduled() {
        let work = scheduled
        scheduled = []
        work.forEach { $0.work() }
    }

    // MARK: Disabling

    /// The marker must exist before sleep is disabled, or a crash in between leaves
    /// nothing for recovery to find.
    func testWritesTheMarkerBeforeDisablingSleep() {
        core.connectionOpened()
        XCTAssertTrue(core.request(true, by: 1))
        XCTAssertEqual(control.calls, ["writeMarker", "disable"])
    }

    func testRefusesWhenTheMarkerCannotBeWritten() {
        control.markerWritable = false
        core.connectionOpened()
        XCTAssertFalse(core.request(true, by: 1))
        XCTAssertEqual(control.calls, ["writeMarker"])
    }

    func testRemovesTheMarkerWhenDisablingFails() {
        control.pmsetWorks = false
        core.connectionOpened()
        XCTAssertFalse(core.request(true, by: 1))
        XCTAssertEqual(control.calls, ["writeMarker", "disable", "removeMarker"])
        XCTAssertFalse(control.hasMarker)
    }

    func testAFailedDisableLeavesNoHolderBehind() {
        control.pmsetWorks = false
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.pmsetWorks = true
        control.calls = []
        core.connectionClosed(1)
        XCTAssertEqual(control.calls, [], "nothing was held, so nothing to restore")
    }

    // MARK: One system-wide setting, many connections

    func testASecondHolderDoesNotTouchPmset() {
        core.connectionOpened()
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.calls = []
        XCTAssertTrue(core.request(true, by: 2))
        XCTAssertEqual(control.calls, [])
    }

    func testSleepComesBackOnlyWhenTheLastHolderLetsGo() {
        core.connectionOpened()
        core.connectionOpened()
        _ = core.request(true, by: 1)
        _ = core.request(true, by: 2)
        control.calls = []

        XCTAssertTrue(core.request(false, by: 1))
        XCTAssertEqual(control.calls, [], "connection 2 still holds it")

        XCTAssertTrue(core.request(false, by: 2))
        XCTAssertEqual(control.calls, ["restore", "removeMarker", "sleepIfLidIsClosed"])
    }

    func testAHolderThatDisconnectsIsReleased() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.calls = []
        core.connectionClosed(1)
        XCTAssertEqual(control.calls, ["restore", "removeMarker", "sleepIfLidIsClosed"])
    }

    /// A connection rejected by the code-signing check, or one that never disabled
    /// sleep, must not trigger anything privileged when it goes away.
    func testAConnectionThatNeverHeldSleepTriggersNothing() {
        core.connectionOpened()
        core.connectionClosed(7)
        XCTAssertEqual(control.calls, [])
    }

    func testRepeatingARequestIsHarmless() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.calls = []
        XCTAssertTrue(core.request(true, by: 1))
        XCTAssertTrue(core.request(false, by: 1))
        XCTAssertTrue(core.request(false, by: 1))
        XCTAssertEqual(control.calls, ["restore", "removeMarker", "sleepIfLidIsClosed"])
    }

    // MARK: Restoring keeps trying

    func testAFailedRestoreKeepsTheMarkerAndRetries() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.pmsetWorks = false
        control.calls = []

        XCTAssertFalse(core.request(false, by: 1))
        XCTAssertEqual(control.calls, ["restore"])
        XCTAssertTrue(control.hasMarker)
        XCTAssertEqual(scheduled.map(\.delay), [5])

        control.pmsetWorks = true
        runScheduled()
        XCTAssertEqual(control.calls, ["restore", "restore", "removeMarker", "sleepIfLidIsClosed"])
        XCTAssertFalse(control.hasMarker)
    }

    func testKeepsRetryingUntilRestoreWorks() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.pmsetWorks = false
        _ = core.request(false, by: 1)
        runScheduled()
        XCTAssertEqual(scheduled.count, 1, "still failing, so another retry is queued")
    }

    /// The app retries too; it must hear "not yet" until sleep really is back.
    func testTellsTheAppWhileARestoreIsStillPending() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.pmsetWorks = false
        _ = core.request(false, by: 1)
        XCTAssertFalse(core.request(false, by: 1))
        control.pmsetWorks = true
        runScheduled()
        XCTAssertTrue(core.request(false, by: 1))
    }

    func testAPendingRetryStandsDownWhenSomeoneHoldsSleepAgain() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.pmsetWorks = false
        _ = core.request(false, by: 1)
        control.pmsetWorks = true
        XCTAssertTrue(core.request(true, by: 1))
        control.calls = []
        runScheduled()
        XCTAssertEqual(control.calls, [])
    }

    func testDisablingWhileARestoreIsPendingKeepsTheMarkerIfItFails() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.pmsetWorks = false
        _ = core.request(false, by: 1)
        control.calls = []
        XCTAssertFalse(core.request(true, by: 1))
        XCTAssertEqual(control.calls, ["writeMarker", "disable"], "sleep may still be disabled")
        XCTAssertTrue(control.hasMarker)
    }

    // MARK: Recovery and exit

    func testRecoveryRestoresSleepLeftDisabledByAnEarlierRun() {
        control.hasMarker = true
        core.recover()
        XCTAssertEqual(control.calls, ["restore", "removeMarker", "sleepIfLidIsClosed"])
    }

    func testRecoveryWithoutAMarkerDoesNothing() {
        core.recover()
        XCTAssertEqual(control.calls, [])
    }

    func testGoesIdleOnlyWithNoConnectionsHoldersOrPendingRestore() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.pmsetWorks = false
        core.connectionClosed(1)
        XCTAssertEqual(idleCalls, 0, "the restore still has to succeed")
        control.pmsetWorks = true
        runScheduled()
        XCTAssertEqual(idleCalls, 1)
    }

    func testIdleCheckWithAnOpenConnectionStaysUp() {
        core.connectionOpened()
        core.idleCheck()
        XCTAssertEqual(idleCalls, 0)
        core.connectionClosed(1)
        XCTAssertEqual(idleCalls, 1)
    }

    /// launchd stops the helper (unregistered, shutdown): put sleep back on the way out.
    func testShuttingDownRestoresSleepItHolds() {
        core.connectionOpened()
        _ = core.request(true, by: 1)
        control.calls = []
        core.shutDown()
        XCTAssertEqual(control.calls, ["restore", "removeMarker"])
    }

    func testShuttingDownWithNothingHeldLeavesSleepAlone() {
        core.shutDown()
        XCTAssertEqual(control.calls, [])
    }

    func testShuttingDownKeepsTheMarkerWhenRestoreFails() {
        control.hasMarker = true
        control.pmsetWorks = false
        core.shutDown()
        XCTAssertEqual(control.calls, ["restore"])
        XCTAssertTrue(control.hasMarker)
    }
}

/// Stands in for `pmset` and the marker file; records every call in order.
final class FakeSleepControl: SleepControlling {
    var calls: [String] = []
    var hasMarker = false
    var markerWritable = true
    var pmsetWorks = true

    func writeMarker() -> Bool {
        calls.append("writeMarker")
        guard markerWritable else { return false }
        hasMarker = true
        return true
    }

    func removeMarker() {
        calls.append("removeMarker")
        hasMarker = false
    }

    func setSleepDisabled(_ disabled: Bool) -> Bool {
        calls.append(disabled ? "disable" : "restore")
        return pmsetWorks
    }

    func sleepIfLidIsClosed() {
        calls.append("sleepIfLidIsClosed")
    }
}
