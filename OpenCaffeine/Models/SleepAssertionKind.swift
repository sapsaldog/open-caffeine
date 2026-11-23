import IOKit.pwr_mgt

/// Which kind of idle sleep the power assertion blocks.
///
/// `.displayAndSystem` keeps the display on and the system awake, matching what
/// users expect from a "keep awake" toggle. `.systemOnly` keeps the system running
/// but lets the display sleep, useful for unattended work like long downloads.
enum SleepAssertionKind: Equatable {
    case displayAndSystem
    case systemOnly

    init(keepDisplayAwake: Bool) {
        self = keepDisplayAwake ? .displayAndSystem : .systemOnly
    }

    /// IOKit assertion types to hold; `SleepAssertion` creates one assertion per type.
    ///
    /// `.displayAndSystem` holds the system assertion too. Apple documents the
    /// display assertion as blocking idle system sleep only while it keeps the
    /// display from dimming, and the display can still be turned off on purpose
    /// (Display Off, a hot corner, the keyboard shortcut) — the Mac must stay awake.
    var ioKitAssertionTypes: [String] {
        switch self {
        case .displayAndSystem:
            return [kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertPreventUserIdleSystemSleep]
        case .systemOnly:
            return [kIOPMAssertPreventUserIdleSystemSleep]
        }
    }
}
