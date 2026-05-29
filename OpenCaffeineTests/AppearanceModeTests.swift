import AppKit
@testable import OpenCaffeine
import XCTest

final class AppearanceModeTests: XCTestCase {
    func testRawValuesRoundTrip() {
        XCTAssertEqual(AppearanceMode(rawValue: "auto"), .auto)
        XCTAssertEqual(AppearanceMode(rawValue: "light"), .light)
        XCTAssertEqual(AppearanceMode(rawValue: "dark"), .dark)
        XCTAssertNil(AppearanceMode(rawValue: "nope"))
    }

    func testDisplayNames() {
        XCTAssertEqual(AppearanceMode.auto.displayName, "Auto")
        XCTAssertEqual(AppearanceMode.light.displayName, "Light")
        XCTAssertEqual(AppearanceMode.dark.displayName, "Dark")
    }

    func testIdentifiableUsesRawValue() {
        XCTAssertEqual(AppearanceMode.dark.id, "dark")
    }

    func testAutoInheritsSystemAppearance() {
        XCTAssertNil(AppearanceMode.auto.nsAppearance)
    }

    func testLightAndDarkMapToConcreteAppearances() {
        XCTAssertEqual(AppearanceMode.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(AppearanceMode.dark.nsAppearance?.name, .darkAqua)
    }

    func testAllCasesPresent() {
        XCTAssertEqual(AppearanceMode.allCases, [.auto, .light, .dark])
    }
}
