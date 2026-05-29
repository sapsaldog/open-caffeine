import Combine
@testable import OpenCaffein
import XCTest

final class AppSettingsTests: XCTestCase {
    private let keys = [
        "iconStyle", "startAtLogin", "showIconInDock", "showInstructionMessage",
        "showCountdown", "keepDisplayAwake", "appearanceMode", "defaultDurationSeconds",
        "sleepBelowBatteryPercent", "didShowInstructionMessage"
    ]
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        cancellables.removeAll()
        super.tearDown()
    }

    func testDefaultsMatchSpec() {
        let settings = AppSettings()
        XCTAssertEqual(settings.iconStyleRaw, MenuBarIconStyle.coffeeType1.rawValue)
        XCTAssertFalse(settings.startAtLogin)
        XCTAssertFalse(settings.showIconInDock)
        XCTAssertFalse(settings.showInstructionMessage)
        XCTAssertTrue(settings.showCountdown)
        XCTAssertTrue(settings.keepDisplayAwake)
        XCTAssertEqual(settings.appearanceModeRaw, "auto")
        XCTAssertEqual(settings.defaultDurationSeconds, -1)
        XCTAssertEqual(settings.sleepBelowBatteryPercent, 0)
        XCTAssertFalse(settings.didShowInstructionMessage)
    }

    func testEachStoredPropertyPersists() {
        let settings = AppSettings()
        settings.startAtLogin = true
        settings.showIconInDock = true
        settings.showInstructionMessage = true
        settings.showCountdown = false
        settings.keepDisplayAwake = false
        settings.appearanceModeRaw = "dark"
        settings.sleepBelowBatteryPercent = 20
        settings.didShowInstructionMessage = true

        let reloaded = AppSettings()
        XCTAssertTrue(reloaded.startAtLogin)
        XCTAssertTrue(reloaded.showIconInDock)
        XCTAssertTrue(reloaded.showInstructionMessage)
        XCTAssertFalse(reloaded.showCountdown)
        XCTAssertFalse(reloaded.keepDisplayAwake)
        XCTAssertEqual(reloaded.appearanceModeRaw, "dark")
        XCTAssertEqual(reloaded.sleepBelowBatteryPercent, 20)
        XCTAssertTrue(reloaded.didShowInstructionMessage)
    }

    func testIconStyleGetAndSet() {
        let settings = AppSettings()
        XCTAssertEqual(settings.iconStyle, .coffeeType1)
        settings.iconStyle = .coffeeType3
        XCTAssertEqual(settings.iconStyleRaw, "coffeeType3")
        XCTAssertEqual(settings.iconStyle, .coffeeType3)
    }

    func testIconStyleFallsBackOnUnknownRawValue() {
        let settings = AppSettings()
        settings.iconStyleRaw = "not-a-real-style"
        XCTAssertEqual(settings.iconStyle, .coffeeType1)
    }

    func testAppearanceModeGetAndSet() {
        let settings = AppSettings()
        XCTAssertEqual(settings.appearanceMode, .auto)
        settings.appearanceMode = .dark
        XCTAssertEqual(settings.appearanceModeRaw, "dark")
        XCTAssertEqual(settings.appearanceMode, .dark)
    }

    func testAppearanceModeFallsBackOnUnknownRawValue() {
        let settings = AppSettings()
        settings.appearanceModeRaw = "bogus"
        XCTAssertEqual(settings.appearanceMode, .auto)
    }

    func testDefaultDurationIsForeverWhenNegative() {
        let settings = AppSettings()
        settings.defaultDurationSeconds = -1
        XCTAssertEqual(settings.defaultDuration, .forever)
    }

    func testDefaultDurationReconstructsPreset() {
        let settings = AppSettings()
        settings.defaultDuration = .minutes(30)
        XCTAssertEqual(settings.defaultDurationSeconds, 1800)
        XCTAssertEqual(settings.defaultDuration, .minutes(30))
    }

    func testDefaultDurationFallsBackToCustom() {
        let settings = AppSettings()
        settings.defaultDurationSeconds = 123
        XCTAssertEqual(settings.defaultDuration, .custom(seconds: 123))
    }

    func testSettingDefaultDurationForeverStoresNegative() {
        let settings = AppSettings()
        settings.defaultDuration = .forever
        XCTAssertEqual(settings.defaultDurationSeconds, -1)
    }

    func testObjectWillChangeBridgesDefaultsNotification() {
        let settings = AppSettings()
        let changed = expectation(description: "objectWillChange forwarded")
        settings.objectWillChange.sink { _ in changed.fulfill() }.store(in: &cancellables)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        wait(for: [changed], timeout: 2.0)
    }
}
