import SwiftUI

/// Preferences in Tahoe's System Settings layout, built as a custom split so the
/// 52pt top bar (traffic lights · sidebar header · detail title + divider) lines
/// up exactly with the design — instead of NavigationSplitView's own chrome.
struct PreferencesScene: View {
    @StateObject private var settings = AppSettings.shared
    private let loginItem = LoginItemManager()
    let onDockVisibilityChange: (Bool) -> Void

    @State private var page: PrefPage = .general

    enum PrefPage: Hashable {
        case general, battery, updates, feedback
        var title: String {
            switch self {
            case .general: return "General"
            case .battery: return "Duration & Battery"
            case .updates: return "Updates"
            case .feedback: return "Feedback"
            }
        }
    }

    private let topBar: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 720, height: 500)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: topBar)          // traffic-light strip
            HStack(spacing: 10) {
                Image("AppGlyph").resizable().frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Open Caffeine").font(.system(size: 13, weight: .semibold))
                    Text("Version \(appVersion)").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            VStack(spacing: 2) {
                NavRow(title: "General", systemImage: "gearshape", tint: .gray,
                       selected: page == .general) { page = .general }
                NavRow(title: "Duration & Battery", systemImage: "clock", tint: .indigo,
                       selected: page == .battery) { page = .battery }
                NavRow(title: "Updates", systemImage: "arrow.down.circle", tint: .green,
                       selected: page == .updates) { page = .updates }
                NavRow(title: "Feedback", systemImage: "text.bubble", tint: .pink,
                       selected: page == .feedback) { page = .feedback }
            }
            .padding(.horizontal, 10)
            Spacer()
        }
        .frame(width: 216)
        .background(.regularMaterial)
    }

    // MARK: Detail

    private var detail: some View {
        VStack(spacing: 0) {
            HStack {
                Text(page.title).font(.system(size: 15, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: topBar)
            Divider()

            switch page {
            case .general:
                GeneralSettingsView(
                    settings: settings,
                    loginItem: loginItem,
                    onDockVisibilityChange: onDockVisibilityChange
                )
            case .battery:
                DurationSettingsView(settings: settings)
            case .updates:
                UpdatesSettingsView(settings: settings)
            case .feedback:
                FeedbackSettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .toggleStyle(.switch)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

/// Sidebar nav row with a colored glyph tile (System Settings style).
private struct NavRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(tint, in: RoundedRectangle(cornerRadius: 5))
                Text(title).font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background {
                if selected { RoundedRectangle(cornerRadius: 7).fill(Color.accentColor) }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
