@testable import OpenCaffeine
import XCTest

/// The helper's live `SleepControlling`, with `pmset` and the kernel flag faked.
final class PMSetSleepControlTests: XCTestCase {
    private var folder: URL!
    private var commands: [[String]] = []
    private var exitsCleanly = true
    /// What `SleepDisabled` reads, in order; the last value repeats.
    private var readings: [Bool?] = [true]
    private var reads = 0
    /// What the saved setting (`pmset -g`) reads; `nil` = same as the kernel.
    private var savedReadings: [Bool?]?
    private var savedReads = 0
    private var lidShouldSleep = false
    /// A fake clock: pauses advance it, and so does each saved read by `savedReadCost`.
    private var clock = Date(timeIntervalSince1970: 0)
    private var savedReadCost: TimeInterval = 0
    private var control: PMSetSleepControl!

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        commands = []
        exitsCleanly = true
        readings = [true]
        reads = 0
        savedReadings = nil
        savedReads = 0
        lidShouldSleep = false
        clock = Date(timeIntervalSince1970: 0)
        savedReadCost = 0
        control = makeControl(marker: folder.appendingPathComponent("Open Caffeine/helper-disabled-sleep"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
        try super.tearDownWithError()
    }

    private func makeControl(marker: URL) -> PMSetSleepControl {
        PMSetSleepControl(
            marker: marker,
            maxWait: 0.25,
            run: { [unowned self] arguments in
                commands.append(arguments)
                return exitsCleanly
            },
            readSleepDisabled: { [unowned self] in
                defer { reads += 1 }
                return readings[min(reads, readings.count - 1)]
            },
            readSavedSleepDisabled: { [unowned self] in
                clock += savedReadCost
                guard let savedReadings else { return readings[min(reads - 1, readings.count - 1)] }
                defer { savedReads += 1 }
                return savedReadings[min(savedReads, savedReadings.count - 1)]
            },
            lidShouldSleep: { [unowned self] in lidShouldSleep },
            now: { [unowned self] in clock },
            pause: { [unowned self] seconds in clock += seconds }
        )
    }

    // MARK: pmset, checked against the kernel

    func testDisablingRunsPmsetAndConfirmsWithTheKernel() {
        XCTAssertTrue(control.setSleepDisabled(true))
        XCTAssertEqual(commands, [["-a", "disablesleep", "1"]])
    }

    func testRestoringRunsPmsetAndConfirmsWithTheKernel() {
        readings = [false]
        XCTAssertTrue(control.setSleepDisabled(false))
        XCTAssertEqual(commands, [["-a", "disablesleep", "0"]])
    }

    /// pmset can print an error and still exit 0: only the kernel's flag counts.
    func testAZeroExitThatChangedNothingIsAFailure() {
        readings = [false]
        XCTAssertFalse(control.setSleepDisabled(true))
        XCTAssertEqual(reads, 4, "checked every 0.1 s until the 0.25 s wait ran out")
    }

    func testWaitsBrieflyForTheKernelToCatchUp() {
        readings = [false, false, true]
        XCTAssertTrue(control.setSleepDisabled(true))
    }

    /// A rollback that didn't save, while the kernel still shows the old value, must
    /// not pass: the saved setting would re-apply later with nothing left to undo it.
    func testTheSavedSettingHasToMatchToo() {
        readings = [false]
        savedReadings = [true]
        XCTAssertFalse(control.setSleepDisabled(false))
    }

    func testBothSettledIsASuccess() {
        readings = [false, true]
        savedReadings = [false, true]
        XCTAssertTrue(control.setSleepDisabled(true))
    }

    /// Each pmset run has its own timeout; the wait as a whole must have one too, or
    /// slow reads could outlast launchd's termination window.
    func testStopsWaitingAtTheDeadlineEvenWhenReadsAreSlow() {
        readings = [true]
        savedReadings = [false]
        savedReadCost = 5
        XCTAssertFalse(control.setSleepDisabled(true))
        XCTAssertEqual(savedReads, 1, "one slow read already passed the deadline")
    }

    func testANonZeroExitIsAFailureWithoutReadingBack() {
        exitsCleanly = false
        XCTAssertFalse(control.setSleepDisabled(true))
        XCTAssertEqual(reads, 0)
    }

    func testAnUnreadableFlagIsAFailure() {
        readings = [nil]
        XCTAssertFalse(control.setSleepDisabled(false))
    }

    // MARK: Reading `pmset -g`

    func testReadsTheSavedFlagFromPmsetOutput() {
        let set = "System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n sleep 0\n"
        XCTAssertEqual(PMSetSleepControl.savedSleepDisabled(fromPMSetOutput: set), true)
        XCTAssertEqual(PMSetSleepControl.savedSleepDisabled(fromPMSetOutput: " SleepDisabled 0\n"), false)
    }

    /// pmset only lists SleepDisabled once it has been set.
    func testAMissingLineMeansNotDisabled() {
        XCTAssertEqual(PMSetSleepControl.savedSleepDisabled(fromPMSetOutput: "Currently in use:\n sleep 0\n"), false)
    }

    func testNoOutputIsUnknown() {
        XCTAssertNil(PMSetSleepControl.savedSleepDisabled(fromPMSetOutput: nil))
        XCTAssertNil(PMSetSleepControl.savedSleepDisabled(fromPMSetOutput: ""))
    }

    // MARK: Marker file

    func testTheMarkerIsWrittenAndRemoved() {
        XCTAssertFalse(control.hasMarker)
        XCTAssertTrue(control.writeMarker())
        XCTAssertTrue(control.hasMarker)
        control.removeMarker()
        XCTAssertFalse(control.hasMarker)
        control.removeMarker()  // already gone: still fine
        XCTAssertFalse(control.hasMarker)
    }

    func testAMarkerThatCannotBeWrittenIsReported() throws {
        let blocker = folder.appendingPathComponent("not-a-folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: blocker)
        let blocked = makeControl(marker: blocker.appendingPathComponent("helper-disabled-sleep"))
        XCTAssertFalse(blocked.writeMarker())
        XCTAssertFalse(blocked.hasMarker)
    }

    func testAMarkerThatCannotBeRemovedIsLogged() throws {
        let marker = folder.appendingPathComponent("Open Caffeine/helper-disabled-sleep")
        XCTAssertTrue(control.writeMarker())
        let locked = marker.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        control.removeMarker()
        XCTAssertTrue(control.hasMarker, "still there; the next start retries the restore")
    }

    // MARK: Sleeping a shut lid

    func testSleepsWhenTheLidIsShut() {
        lidShouldSleep = true
        control.sleepIfLidIsClosed()
        XCTAssertEqual(commands, [["sleepnow"]])
    }

    func testLeavesAnOpenLidAlone() {
        control.sleepIfLidIsClosed()
        XCTAssertEqual(commands, [])
    }
}
