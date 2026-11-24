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
    private var lidShouldSleep = false
    private var control: PMSetSleepControl!

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        commands = []
        exitsCleanly = true
        readings = [true]
        reads = 0
        lidShouldSleep = false
        control = makeControl(marker: folder.appendingPathComponent("Open Caffeine/helper-disabled-sleep"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
        try super.tearDownWithError()
    }

    private func makeControl(marker: URL) -> PMSetSleepControl {
        PMSetSleepControl(
            marker: marker,
            checks: 3,
            run: { [unowned self] arguments in
                commands.append(arguments)
                return exitsCleanly
            },
            readSleepDisabled: { [unowned self] in
                defer { reads += 1 }
                return readings[min(reads, readings.count - 1)]
            },
            lidShouldSleep: { [unowned self] in lidShouldSleep },
            pause: { _ in }
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
        XCTAssertEqual(reads, 3, "checked a few times before giving up")
    }

    func testWaitsBrieflyForTheKernelToCatchUp() {
        readings = [false, false, true]
        XCTAssertTrue(control.setSleepDisabled(true))
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
