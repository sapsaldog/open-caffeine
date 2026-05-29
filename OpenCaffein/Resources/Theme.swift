import SwiftUI

// macOS 26 (Tahoe) design tokens, mapped to native system semantics so dark
// mode and the user's accent tint come for free. Pure declarative styling —
// excluded from the coverage gate alongside the SwiftUI view bodies.

enum Tokens {
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xLarge: CGFloat = 16
        static let xxLarge: CGFloat = 22
        static let pill: CGFloat = 999
    }

    enum Space {
        static let row: CGFloat = 44     // grouped settings row min height
        static let chip: CGFloat = 32    // duration chip height
    }
}

extension Font {
    /// HIG macOS text styles (point sizes from the Tahoe type scale).
    static let macControl = Font.system(size: 13, weight: .medium)
    static let macHeadline = Font.system(size: 13, weight: .semibold)
    static let macBody = Font.system(size: 13)
    static let macCallout = Font.system(size: 12)
    static let macSubheadline = Font.system(size: 11)
    static let macTitle2 = Font.system(size: 17)
    static let macTitle3 = Font.system(size: 15, weight: .semibold)

    /// Rounded, tabular countdown readout (matches `--font-rounded`).
    static func macCountdown(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}
