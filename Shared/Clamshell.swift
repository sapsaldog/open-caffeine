import Foundation
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
        guard let closed = RootDomain.flag(kAppleClamshellStateKey) else { return nil }
        return Clamshell(closed: closed, causesSleep: RootDomain.flag(kAppleClamshellCausesSleepKey) ?? true)
    }
}
