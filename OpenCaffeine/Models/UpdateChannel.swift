import Foundation

/// Which release stream the app offers updates from. `.beta` opts into
/// pre-release builds.
enum UpdateChannel: String, CaseIterable, Identifiable {
    case stable
    case beta

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stable: return String(localized: "Stable", comment: "Update channel: regular releases")
        case .beta: return String(localized: "Beta", comment: "Update channel: pre-release builds")
        }
    }
}
