import Foundation
import IOKit.ps

/// Live battery readings via IOKit. The raw power-source fetch is an irreducible
/// system boundary and is excluded from the coverage gate; the parsing logic lives
/// in `BatterySnapshotParser` and is fully unit-tested.
struct SystemBatteryProvider: BatteryProvider, PowerStatusProviding {
    func currentBattery() -> (hasBattery: Bool, percent: Int) {
        BatterySnapshotParser.parse(Self.powerSourceDescriptions())
    }

    func currentPowerStatus() -> PowerStatus {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        return BatterySnapshotParser.powerStatus(providingType: type, descriptions: Self.powerSourceDescriptions())
    }

    static func powerSourceDescriptions() -> [[String: AnyObject]] {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        return sources.compactMap {
            IOPSGetPowerSourceDescription(snapshot, $0)?.takeUnretainedValue() as? [String: AnyObject]
        }
    }
}
