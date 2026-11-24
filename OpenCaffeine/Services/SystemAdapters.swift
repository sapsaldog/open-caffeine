import Foundation
import IOKit.pwr_mgt
import KeyboardShortcuts
import os.log
import ServiceManagement

// Live, OS-touching implementations of the service seams. Everything here is a
// thin pass-through to a system API with no branching logic of its own, so it is
// excluded from the coverage gate (see Scripts/coverage-gate.sh). The testable
// logic lives in the corresponding `*Providing` / `*Controlling` types.

// MARK: - Sleep assertion (IOKit power management)

struct IOKitPowerAssertionAPI: PowerAssertionAPI {
    func create(type: String, reason: String, id: inout IOPMAssertionID) -> IOReturn {
        IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
    }

    func release(id: IOPMAssertionID) -> IOReturn {
        IOPMAssertionRelease(id)
    }
}

// MARK: - Display sleep (pmset)

/// `pmset displaysleepnow`: every display sleeps right away and the Mac keeps
/// running. Needs no admin rights. A failure only shows up as the exit status,
/// which arrives after `run()` returns, so it is logged rather than thrown.
struct PMSetDisplaySleeper: DisplaySleeping {
    private static let log = Logger(subsystem: "com.opencaffeine", category: "display")

    func sleepDisplayNow() throws {
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["displaysleepnow"]
        pmset.terminationHandler = { process in
            guard process.terminationStatus != 0 else { return }
            Self.log.error("pmset displaysleepnow exited with status \(process.terminationStatus)")
        }
        try pmset.run()
    }
}

/// `pmset sleepnow`, like choosing Sleep from the Apple menu. The console user may
/// run it without admin rights; a failure shows up only in the exit status.
struct PMSetSystemSleeper: SystemSleeping {
    private static let log = Logger(subsystem: "com.opencaffeine", category: "lid")

    func sleepNow() throws {
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["sleepnow"]
        pmset.terminationHandler = { process in
            guard process.terminationStatus != 0 else { return }
            Self.log.error("pmset sleepnow exited with status \(process.terminationStatus)")
        }
        try pmset.run()
    }
}

// MARK: - Login item (ServiceManagement)

extension SMAppService: LoginItemControlling {
    var isRegistered: Bool { status == .enabled }
}

// MARK: - Global hot key (KeyboardShortcuts)

extension KeyboardShortcuts.Name {
    static let toggleCaffeine = Self("toggleCaffeine")
}

func registerToggleHotKey(_ handler: @escaping () -> Void) {
    KeyboardShortcuts.onKeyDown(for: .toggleCaffeine, action: handler)
}
