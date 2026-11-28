import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case coffeeType1
    case coffeeType2
    case coffeeType3

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coffeeType1: return String(localized: "Coffee Type 1", comment: "Menu bar icon style name")
        case .coffeeType2: return String(localized: "Coffee Type 2", comment: "Menu bar icon style name")
        case .coffeeType3: return String(localized: "Coffee Type 3", comment: "Menu bar icon style name")
        }
    }
}
