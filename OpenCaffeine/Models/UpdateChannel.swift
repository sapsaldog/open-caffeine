import Foundation

/// Which release stream the app offers updates from. `.beta` opts into
/// pre-release builds.
enum UpdateChannel: String, CaseIterable, Identifiable {
    case stable
    case beta

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        }
    }
}
