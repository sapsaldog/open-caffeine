import Foundation
import IOKit
import IOKit.pwr_mgt

/// A MacBook's lid as IOPMrootDomain reports it. Used by the app and the helper.
struct Clamshell: Equatable {
    /// The lid is shut.
    var closed: Bool
    /// macOS sleeps for a shut lid — false in closed-display mode (external display on power).
    var causesSleep: Bool

    /// A shut lid that should have the Mac asleep.
    var shouldSleep: Bool { closed && causesSleep }

    /// `nil` on Macs without a lid.
    static func current() -> Clamshell? {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }
        func flag(_ key: String) -> Bool? {
            IORegistryEntryCreateCFProperty(root, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
        }
        guard let closed = flag(kAppleClamshellStateKey) else { return nil }
        return Clamshell(closed: closed, causesSleep: flag(kAppleClamshellCausesSleepKey) ?? true)
    }
}
