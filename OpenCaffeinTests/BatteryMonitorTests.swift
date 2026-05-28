@testable import OpenCaffein
import XCTest

final class BatteryMonitorTests: XCTestCase {
    func testNoCallbackWhenDisabled() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 5)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 0 }, onLow: { fired = true })
        monitor.evaluate()
        XCTAssertFalse(fired)
    }

    func testCallbackFiresBelowThreshold() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 9)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 10 }, onLow: { fired = true })
        monitor.evaluate()
        XCTAssertTrue(fired)
    }

    func testCallbackDoesNotFireAboveThreshold() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 25)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 10 }, onLow: { fired = true })
        monitor.evaluate()
        XCTAssertFalse(fired)
    }

    func testCallbackNeverFiresWithoutBattery() {
        let provider = FakeBatteryProvider(hasBattery: false, percent: 0)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 20 }, onLow: { fired = true })
        monitor.evaluate()
        XCTAssertFalse(fired)
    }

    func testHandleNotificationWithNilContextIsNoOp() {
        BatteryMonitor.handleNotification(nil)
    }

    func testHandleNotificationEvaluatesReferencedMonitor() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 5)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 10 }, onLow: { fired = true })
        BatteryMonitor.handleNotification(Unmanaged.passUnretained(monitor).toOpaque())
        XCTAssertTrue(fired)
    }

    func testPowerSourceTrampolineEvaluatesReferencedMonitor() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 1)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 5 }, onLow: { fired = true })
        batteryPowerSourceDidChange(Unmanaged.passUnretained(monitor).toOpaque())
        XCTAssertTrue(fired)
    }

    func testStartThenStopObservingIsIdempotent() {
        let monitor = BatteryMonitor(
            provider: FakeBatteryProvider(hasBattery: false, percent: 0),
            threshold: { 0 },
            onLow: {}
        )
        monitor.startObserving()
        monitor.startObserving()
        monitor.stopObserving()
        monitor.stopObserving()
    }
}

final class FakeBatteryProvider: BatteryProvider {
    var hasBattery: Bool
    var percent: Int
    init(hasBattery: Bool, percent: Int) {
        self.hasBattery = hasBattery
        self.percent = percent
    }
    func currentBattery() -> (hasBattery: Bool, percent: Int) {
        (hasBattery, percent)
    }
}
