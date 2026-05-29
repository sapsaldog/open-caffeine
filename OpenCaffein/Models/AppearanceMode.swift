import AppKit

/// App appearance override. `auto` follows the macOS system Light/Dark setting;
/// `light`/`dark` force it regardless of the system.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The `NSAppearance` to apply to `NSApp`. `nil` for `auto` (inherit system).
    var nsAppearance: NSAppearance? {
        switch self {
        case .auto: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}
