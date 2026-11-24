import Foundation
import IOKit.ps
import os.log

protocol BatteryProvider {
    func currentBattery() -> (hasBattery: Bool, percent: Int)
}

/// Where the Mac draws power from, and the battery charge (0 without a battery).
struct PowerStatus: Equatable {
    var onBattery: Bool
    var batteryPercent: Int
}

protocol PowerStatusProviding {
    func currentPowerStatus() -> PowerStatus
}

/// Pure parsing of IOKit power-source descriptions into a battery snapshot.
enum BatterySnapshotParser {
    static func parse(_ descriptions: [[String: AnyObject]]) -> (hasBattery: Bool, percent: Int) {
        for desc in descriptions {
            if let maxCap = desc[kIOPSMaxCapacityKey] as? Int,
               let current = desc[kIOPSCurrentCapacityKey] as? Int,
               maxCap > 0 {
                return (true, Int((Double(current) / Double(maxCap)) * 100))
            }
        }
        return (false, 0)
    }

    /// - Parameter providingType: `IOPSGetProvidingPowerSourceType`, e.g. `kIOPSBatteryPowerValue`.
    static func powerStatus(providingType: String?, descriptions: [[String: AnyObject]]) -> PowerStatus {
        PowerStatus(onBattery: providingType == kIOPSBatteryPowerValue, batteryPercent: parse(descriptions).percent)
    }
}

final class BatteryMonitor {
    private let log = Logger(subsystem: "com.opencaffeine", category: "battery")
    private let provider: BatteryProvider
    private let threshold: () -> Int
    private let onLow: () -> Void
    private let onChange: () -> Void
    private var runLoopSource: CFRunLoopSource?

    init(
        provider: BatteryProvider = SystemBatteryProvider(),
        threshold: @escaping () -> Int,
        onLow: @escaping () -> Void,
        onChange: @escaping () -> Void = {}
    ) {
        self.provider = provider
        self.threshold = threshold
        self.onLow = onLow
        self.onChange = onChange
    }

    deinit { stopObserving() }

    /// Called synchronously by tests and by the IOPS callback (which runs on the main runloop).
    func evaluate() {
        onChange()
        let snapshot = provider.currentBattery()
        let limit = threshold()
        guard limit > 0, snapshot.hasBattery, snapshot.percent < limit else { return }
        onLow()
    }

    func startObserving() {
        stopObserving()
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource(batteryPowerSourceDidChange, context)
            .takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    func stopObserving() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
    }

    /// Bridges the capture-free C power-source callback to `evaluate()`.
    static func handleNotification(_ context: UnsafeMutableRawPointer?) {
        guard let context else { return }
        Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().evaluate()
    }
}

/// Capture-free trampoline so it converts to a C function pointer for IOKit.
/// Invoked by IOKit on power-source changes; also exercised directly in tests.
func batteryPowerSourceDidChange(_ context: UnsafeMutableRawPointer?) {
    BatteryMonitor.handleNotification(context)
}
