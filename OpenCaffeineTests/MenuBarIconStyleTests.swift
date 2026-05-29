@testable import OpenCaffeine
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
}
