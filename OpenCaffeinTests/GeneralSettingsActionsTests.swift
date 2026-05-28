@testable import OpenCaffein
import XCTest

@MainActor
final class GeneralSettingsActionsTests: XCTestCase {
    private let keys = ["iconStyle", "startAtLogin", "showIconInDock"]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    private struct Harness {
        let actions: GeneralSettingsActions
        let settings: AppSettings
        let service: FakeLoginItemService
    }

    private func makeHarness(onDock: @escaping (Bool) -> Void = { _ in }) -> Harness {
        let settings = AppSettings()
        let service = FakeLoginItemService()
        let actions = GeneralSettingsActions(
            settings: settings,
            loginItem: LoginItemManager(service: service),
            onDockVisibilityChange: onDock
        )
        return Harness(actions: actions, settings: settings, service: service)
    }

    func testSetIconStyleUpdatesSettings() {
        let harness = makeHarness()
        harness.actions.setIconStyle(.coffeeType2)
        XCTAssertEqual(harness.settings.iconStyle, .coffeeType2)
    }

    func testSetStartAtLoginEnablesAndSyncsLoginItem() {
        let harness = makeHarness()
        harness.actions.setStartAtLogin(true)
        XCTAssertTrue(harness.settings.startAtLogin)
        XCTAssertEqual(harness.service.registerCount, 1)
    }

    func testSetStartAtLoginDisablesAndSyncsLoginItem() {
        let harness = makeHarness()
        harness.service.isRegistered = true
        harness.actions.setStartAtLogin(false)
        XCTAssertFalse(harness.settings.startAtLogin)
        XCTAssertEqual(harness.service.unregisterCount, 1)
    }

    func testSetShowInDockUpdatesSettingsAndNotifies() {
        var captured: Bool?
        let harness = makeHarness(onDock: { captured = $0 })
        harness.actions.setShowInDock(true)
        XCTAssertTrue(harness.settings.showIconInDock)
        XCTAssertEqual(captured, true)
    }
}
