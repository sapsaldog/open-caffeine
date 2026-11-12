import AppKit
@testable import OpenCaffeine
import XCTest

final class AppLaunchLogicTests: XCTestCase {
    func testActivationPolicyRegularWhenDockVisible() {
        XCTAssertEqual(AppLaunchLogic.activationPolicy(forDockVisible: true), .regular)
    }

    func testActivationPolicyAccessoryWhenDockHidden() {
        XCTAssertEqual(AppLaunchLogic.activationPolicy(forDockVisible: false), .accessory)
    }

    func testShowsInstructionWhenEnabledAndNotYetShown() {
        XCTAssertTrue(AppLaunchLogic.shouldShowInstructionMessage(showInstructionMessage: true, alreadyShown: false))
    }

    func testDoesNotShowWhenDisabled() {
        XCTAssertFalse(AppLaunchLogic.shouldShowInstructionMessage(showInstructionMessage: false, alreadyShown: false))
    }

    func testDoesNotShowWhenAlreadyShown() {
        XCTAssertFalse(AppLaunchLogic.shouldShowInstructionMessage(showInstructionMessage: true, alreadyShown: true))
    }

    func testNormalLaunchIsNotATestHost() {
        XCTAssertFalse(AppLaunchLogic.isRunningAsTestHost(environment: [:]))
    }

    func testDetectsTheXCTestHostEnvironment() {
        let environment = ["XCTestConfigurationFilePath": "/tmp/OpenCaffeineTests.xctestconfiguration"]
        XCTAssertTrue(AppLaunchLogic.isRunningAsTestHost(environment: environment))
    }

    func testThisTestRunIsDetectedAsATestHost() {
        // Fails if a future Xcode stops setting the variable the check relies on.
        XCTAssertTrue(AppLaunchLogic.isRunningAsTestHost(environment: ProcessInfo.processInfo.environment))
    }
}
