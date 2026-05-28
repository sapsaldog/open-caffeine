import Foundation
import IOKit.ps
import os.log

protocol BatteryProvider {
    func currentBattery() -> (hasBattery: Bool, percent: Int)
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
}

final class BatteryMonitor {
    private let log = Logger(subsystem: "com.opencaffein", category: "battery")
    private let provider: BatteryProvider
    private let threshold: () -> Int
    private let onLow: () -> Void
    private var runLoopSource: CFRunLoopSource?

    init(
        provider: BatteryProvider = SystemBatteryProvider(),
        threshold: @escaping () -> Int,
        onLow: @escaping () -> Void
    ) {
        self.provider = provider
        self.threshold = threshold
        self.onLow = onLow
    }

    deinit { stopObserving() }

    /// Called synchronously by tests and by the IOPS callback (which runs on the main runloop).
    func evaluate() {
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
