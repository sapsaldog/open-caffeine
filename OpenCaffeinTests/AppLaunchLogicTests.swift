import AppKit
@testable import OpenCaffein
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
}
