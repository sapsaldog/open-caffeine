@testable import OpenCaffein
import XCTest

final class MenuBarIconModelTests: XCTestCase {
    func testAssetNameUsesActiveVariantWhenActive() {
        XCTAssertEqual(MenuBarIconModel.assetName(isActive: true, style: .coffeeType1), "MenuBarIconActive")
    }

    func testAssetNameUsesIdleVariantWhenInactive() {
        XCTAssertEqual(MenuBarIconModel.assetName(isActive: false, style: .coffeeType2), "MenuBarIcon2")
    }

    func testTitleEmptyWhenInactive() {
        XCTAssertEqual(MenuBarIconModel.title(isActive: false, showCountdown: true, remaining: 300), "")
    }

    func testTitleEmptyWhenCountdownDisabled() {
        XCTAssertEqual(MenuBarIconModel.title(isActive: true, showCountdown: false, remaining: 300), "")
    }

    func testTitleShowsCountdownWhenActiveAndEnabled() {
        let expected = " " + CountdownFormatter.string(remaining: 300)
        XCTAssertEqual(MenuBarIconModel.title(isActive: true, showCountdown: true, remaining: 300), expected)
    }
}
