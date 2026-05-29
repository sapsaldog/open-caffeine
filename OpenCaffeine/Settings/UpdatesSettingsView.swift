import SwiftUI

/// The "Updates" preferences tab (design 4): a status block with a Check Now
/// button, an automatic-check toggle, and the update channel. The check is a
/// local simulation — there is no real updater backend wired yet (the app is a
/// local-only build). View shell — excluded from the coverage gate.
struct UpdatesSettingsView: View {
    @ObservedObject var settings: AppSettings

    private enum CheckState { case idle, checking, upToDate }
    @State private var checkState: CheckState = .idle
    @State private var lastChecked = "Today, 9:41 AM"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsGroup { statusRow }

                SettingsGroupLabel(text: "Automatic Updates")
                SettingsGroup {
                    SettingsRow(
                        "Automatically check for updates",
                        subtitle: "Open Caffeine checks once a day in the background.",
                        first: true
                    ) {
                        MacSwitch(isOn: $settings.autoCheckUpdates)
                    }
                }

                SettingsGroupLabel(text: "Update Channel")
                SettingsGroup {
                    SettingsRow(
                        "Receive updates from",
                        subtitle: "Beta builds may be less stable.",
                        first: true
                    ) {
                        Picker("", selection: channelBinding) {
                            ForEach(UpdateChannel.allCases) { channel in
                                Text(channel.displayName).tag(channel)
                            }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
            }
            .padding(20)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 14) {
            Image("AppGlyph")
                .resizable().frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(checkState == .checking ? "Checking for updates…" : "Open Caffeine is up to date")
                    .font(.system(size: 14, weight: .semibold))
                Text("Version \(version) · Last checked \(lastChecked)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button(action: checkNow) {
                Text(checkState == .checking ? "Checking…" : "Check Now").frame(minWidth: 84)
            }
            .buttonStyle(.borderedProminent)
            .disabled(checkState == .checking)
        }
        .padding(16)
    }

    private func checkNow() {
        guard checkState != .checking else { return }
        checkState = .checking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            checkState = .upToDate
            lastChecked = "Just now"
        }
    }

    private var channelBinding: Binding<UpdateChannel> {
        Binding(get: { settings.updateChannel }, set: { settings.updateChannel = $0 })
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
