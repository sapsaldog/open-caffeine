import IOKit.pwr_mgt

/// Which kind of idle sleep the power assertion blocks.
///
/// `.displayAndSystem` keeps the display on — which keeps the system awake too —
/// matching what users expect from a "keep awake" toggle. `.systemOnly` keeps the
/// system running but lets the display sleep, useful for unattended work like long
/// downloads.
enum SleepAssertionKind: Equatable {
    case displayAndSystem
    case systemOnly

    init(keepDisplayAwake: Bool) {
        self = keepDisplayAwake ? .displayAndSystem : .systemOnly
    }

    /// IOKit assertion-type string passed to `IOPMAssertionCreateWithName`.
    var ioKitAssertionType: String {
        switch self {
        case .displayAndSystem: return kIOPMAssertPreventUserIdleDisplaySleep
        case .systemOnly: return kIOPMAssertPreventUserIdleSystemSleep
        }
    }
}
