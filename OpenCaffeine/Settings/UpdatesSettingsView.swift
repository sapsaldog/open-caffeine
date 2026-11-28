import SwiftUI

/// The "Updates" preferences tab (design 4), wired to Sparkle via
/// `UpdaterService`: a status block with a real Check Now button, an
/// automatic-check toggle, and the update channel. View shell — excluded from
/// the coverage gate.
struct UpdatesSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsGroup { statusRow }

                SettingsGroupLabel(text: "Automatic Updates")
                SettingsGroup {
                    SettingsRow(
                        "Automatically check for updates",
                        subtitle: "Open Caffeine checks once a day in the background.",
                        first: true,
                        isOn: autoCheckBinding
                    )
                }

                SettingsGroupLabel(text: "Update Channel")
                SettingsGroup {
                    SettingsRow(
                        "Receive updates from",
                        subtitle: "Beta builds may be less stable.",
                        first: true
                    ) {
                        Picker("Receive updates from", selection: channelBinding) {
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
                .accessibilityHidden(true)  // decorative
            VStack(alignment: .leading, spacing: 2) {
                Text("Open Caffeine is up to date")
                    .font(.system(size: 14, weight: .semibold))
                versionText
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Check Now") { UpdaterService.shared.checkForUpdates() }
                .buttonStyle(.borderedProminent)
                .disabled(!UpdaterService.shared.canCheckForUpdates)
        }
        .padding(16)
    }

    private var autoCheckBinding: Binding<Bool> {
        Binding(
            get: { settings.autoCheckUpdates },
            set: {
                settings.autoCheckUpdates = $0
                UpdaterService.shared.automaticallyChecksForUpdates = $0
            }
        )
    }

    private var channelBinding: Binding<UpdateChannel> {
        Binding(get: { settings.updateChannel }, set: { settings.updateChannel = $0 })
    }

    /// "Version x · Last checked <date>", with the date in the user's locale.
    private var versionText: Text {
        guard let date = UpdaterService.shared.lastUpdateCheckDate else {
            return Text("Version \(version) · Never checked", comment: "Updates status; argument is the app version")
        }
        let checked = date.formatted(date: .abbreviated, time: .shortened)
        return Text(
            "Version \(version) · Last checked \(checked)",
            comment: "Updates status; arguments are the app version and the locale-formatted date of the last check"
        )
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
