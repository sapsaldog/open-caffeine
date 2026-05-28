@testable import OpenCaffein
import XCTest

final class MenuBarIconStyleTests: XCTestCase {
    func testAllCasesHaveDistinctDisplayNames() {
        let names = MenuBarIconStyle.allCases.map(\.displayName)
        XCTAssertEqual(names, ["Coffee Type 1", "Coffee Type 2", "Coffee Type 3"])
    }

    func testIdMatchesRawValueForEveryCase() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertEqual(style.id, style.rawValue)
        }
    }

    func testIdleAssetNamePerCase() {
        XCTAssertEqual(MenuBarIconStyle.coffeeType1.idleAssetName, "MenuBarIcon")
        XCTAssertEqual(MenuBarIconStyle.coffeeType2.idleAssetName, "MenuBarIcon2")
        XCTAssertEqual(MenuBarIconStyle.coffeeType3.idleAssetName, "MenuBarIcon3")
    }

    func testActiveAssetNameAppendsActiveSuffix() {
        XCTAssertEqual(MenuBarIconStyle.coffeeType1.activeAssetName, "MenuBarIconActive")
        XCTAssertEqual(MenuBarIconStyle.coffeeType2.activeAssetName, "MenuBarIcon2Active")
        XCTAssertEqual(MenuBarIconStyle.coffeeType3.activeAssetName, "MenuBarIcon3Active")
    }
}
