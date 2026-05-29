@testable import OpenCaffeine
import XCTest

@MainActor
final class LoginItemManagerTests: XCTestCase {
    func testIsEnabledReflectsServiceRegistration() {
        let service = FakeLoginItemService()
        service.isRegistered = true
        XCTAssertTrue(LoginItemManager(service: service).isEnabled)
    }

    func testSyncEnableRegistersWhenNotRegistered() {
        let service = FakeLoginItemService()
        LoginItemManager(service: service).sync(enabled: true)
        XCTAssertEqual(service.registerCount, 1)
        XCTAssertTrue(service.isRegistered)
    }

    func testSyncEnableIsNoOpWhenAlreadyRegistered() {
        let service = FakeLoginItemService()
        service.isRegistered = true
        LoginItemManager(service: service).sync(enabled: true)
        XCTAssertEqual(service.registerCount, 0)
    }

    func testSyncDisableUnregistersWhenRegistered() {
        let service = FakeLoginItemService()
        service.isRegistered = true
        LoginItemManager(service: service).sync(enabled: false)
        XCTAssertEqual(service.unregisterCount, 1)
        XCTAssertFalse(service.isRegistered)
    }

    func testSyncDisableIsNoOpWhenNotRegistered() {
        let service = FakeLoginItemService()
        LoginItemManager(service: service).sync(enabled: false)
        XCTAssertEqual(service.unregisterCount, 0)
    }

    func testSyncSwallowsServiceError() {
        let service = FakeLoginItemService()
        service.registerError = LoginItemTestError.boom
        LoginItemManager(service: service).sync(enabled: true)
        XCTAssertFalse(service.isRegistered)
    }
}

private enum LoginItemTestError: Error { case boom }

final class FakeLoginItemService: LoginItemControlling {
    var isRegistered = false
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        isRegistered = true
    }

    func unregister() throws {
        unregisterCount += 1
        if let unregisterError { throw unregisterError }
        isRegistered = false
    }
}
