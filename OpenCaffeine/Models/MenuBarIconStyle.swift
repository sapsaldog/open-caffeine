import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case coffeeType1
    case coffeeType2
    case coffeeType3

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coffeeType1: return "Coffee Type 1"
        case .coffeeType2: return "Coffee Type 2"
        case .coffeeType3: return "Coffee Type 3"
        }
    }
}
