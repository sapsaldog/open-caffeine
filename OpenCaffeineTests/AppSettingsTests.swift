import Combine
@testable import OpenCaffeine
import XCTest

final class AppSettingsTests: XCTestCase {
    private let store = TestDefaults()
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        store.remove()
        cancellables.removeAll()
        super.tearDown()
    }

    func testDefaultsMatchSpec() {
        let settings = AppSettings(defaults: store.defaults)
        XCTAssertEqual(settings.iconStyleRaw, MenuBarIconStyle.coffeeType1.rawValue)
        XCTAssertFalse(settings.startAtLogin)
        XCTAssertFalse(settings.showIconInDock)
        XCTAssertFalse(settings.showInstructionMessage)
        XCTAssertTrue(settings.showCountdown)
        XCTAssertFalse(settings.hideCountdownSeconds)
        XCTAssertTrue(settings.keepDisplayAwake)
        XCTAssertEqual(settings.appearanceModeRaw, "auto")
        XCTAssertTrue(settings.autoCheckUpdates)
        XCTAssertEqual(settings.updateChannelRaw, "stable")
        XCTAssertEqual(settings.defaultDurationSeconds, -1)
        XCTAssertEqual(settings.sleepBelowBatteryPercent, 0)
        XCTAssertFalse(settings.didShowInstructionMessage)
    }

    func testEachStoredPropertyPersists() {
        let settings = AppSettings(defaults: store.defaults)
        settings.startAtLogin = true
        settings.showIconInDock = true
        settings.showInstructionMessage = true
        settings.showCountdown = false
        settings.hideCountdownSeconds = true
        settings.keepDisplayAwake = false
        settings.appearanceModeRaw = "dark"
        settings.autoCheckUpdates = false
        settings.updateChannelRaw = "beta"
        settings.sleepBelowBatteryPercent = 20
        settings.didShowInstructionMessage = true

        let reloaded = AppSettings(defaults: store.defaults)
        XCTAssertTrue(reloaded.startAtLogin)
        XCTAssertTrue(reloaded.showIconInDock)
        XCTAssertTrue(reloaded.showInstructionMessage)
        XCTAssertFalse(reloaded.showCountdown)
        XCTAssertTrue(reloaded.hideCountdownSeconds)
        XCTAssertFalse(reloaded.keepDisplayAwake)
        XCTAssertEqual(reloaded.appearanceModeRaw, "dark")
        XCTAssertFalse(reloaded.autoCheckUpdates)
        XCTAssertEqual(reloaded.updateChannelRaw, "beta")
        XCTAssertEqual(reloaded.sleepBelowBatteryPercent, 20)
        XCTAssertTrue(reloaded.didShowInstructionMessage)
    }

    func testIconStyleGetAndSet() {
        let settings = AppSettings(defaults: store.defaults)
        XCTAssertEqual(settings.iconStyle, .coffeeType1)
        settings.iconStyle = .coffeeType3
        XCTAssertEqual(settings.iconStyleRaw, "coffeeType3")
        XCTAssertEqual(settings.iconStyle, .coffeeType3)
    }

    func testIconStyleFallsBackOnUnknownRawValue() {
        let settings = AppSettings(defaults: store.defaults)
        settings.iconStyleRaw = "not-a-real-style"
        XCTAssertEqual(settings.iconStyle, .coffeeType1)
    }

    func testAppearanceModeGetAndSet() {
        let settings = AppSettings(defaults: store.defaults)
        XCTAssertEqual(settings.appearanceMode, .auto)
        settings.appearanceMode = .dark
        XCTAssertEqual(settings.appearanceModeRaw, "dark")
        XCTAssertEqual(settings.appearanceMode, .dark)
    }

    func testAppearanceModeFallsBackOnUnknownRawValue() {
        let settings = AppSettings(defaults: store.defaults)
        settings.appearanceModeRaw = "bogus"
        XCTAssertEqual(settings.appearanceMode, .auto)
    }

    func testUpdateChannelGetAndSet() {
        let settings = AppSettings(defaults: store.defaults)
        XCTAssertEqual(settings.updateChannel, .stable)
        settings.updateChannel = .beta
        XCTAssertEqual(settings.updateChannelRaw, "beta")
        XCTAssertEqual(settings.updateChannel, .beta)
    }

    func testUpdateChannelFallsBackOnUnknownRawValue() {
        let settings = AppSettings(defaults: store.defaults)
        settings.updateChannelRaw = "nope"
        XCTAssertEqual(settings.updateChannel, .stable)
    }

    func testDefaultDurationIsForeverWhenNegative() {
        let settings = AppSettings(defaults: store.defaults)
        settings.defaultDurationSeconds = -1
        XCTAssertEqual(settings.defaultDuration, .forever)
    }

    func testDefaultDurationReconstructsPreset() {
        let settings = AppSettings(defaults: store.defaults)
        settings.defaultDuration = .minutes(30)
        XCTAssertEqual(settings.defaultDurationSeconds, 1800)
        XCTAssertEqual(settings.defaultDuration, .minutes(30))
    }

    func testDefaultDurationFallsBackToCustom() {
        let settings = AppSettings(defaults: store.defaults)
        settings.defaultDurationSeconds = 123
        XCTAssertEqual(settings.defaultDuration, .custom(seconds: 123))
    }

    func testSettingDefaultDurationForeverStoresNegative() {
        let settings = AppSettings(defaults: store.defaults)
        settings.defaultDuration = .forever
        XCTAssertEqual(settings.defaultDurationSeconds, -1)
    }

    func testObjectWillChangeBridgesDefaultsNotification() {
        let settings = AppSettings(defaults: store.defaults)
        let changed = expectation(description: "objectWillChange forwarded")
        settings.objectWillChange.sink { _ in changed.fulfill() }.store(in: &cancellables)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        wait(for: [changed], timeout: 2.0)
    }

    func testWritesGoToTheInjectedStore() {
        let settings = AppSettings(defaults: store.defaults)
        settings.hideCountdownSeconds = true
        XCTAssertEqual(store.defaults.object(forKey: "hideCountdownSeconds") as? Bool, true)
    }
}
