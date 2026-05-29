import Foundation
import IOKit.pwr_mgt
import KeyboardShortcuts
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
