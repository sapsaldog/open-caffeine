import Foundation
import IOKit

/// Read-only flags from IOPMrootDomain — what the kernel itself reports. Any user
/// may read them. Thin IOKit shim (excluded from the coverage gate).
enum RootDomain {
    /// `pmset -a disablesleep` as the kernel applied it; `nil` if it can't be read.
    static var sleepDisabled: Bool? { flag("SleepDisabled") }

    static func flag(_ key: String) -> Bool? {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }
        return IORegistryEntryCreateCFProperty(root, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool
    }
}
