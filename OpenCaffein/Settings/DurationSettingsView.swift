import SwiftUI

struct DurationSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsGroupLabel(text: "Display")
                SettingsGroup {
                    SettingsRow(
                        "Keep the screen on",
                        subtitle: "When off, the Mac stays awake but the display is allowed to sleep.",
                        first: true
                    ) {
                        Toggle("", isOn: $settings.keepDisplayAwake).labelsHidden()
                    }
                }

                SettingsGroupLabel(text: "Countdown")
                SettingsGroup {
                    SettingsRow("Show countdown next to the menu-bar icon", first: true) {
                        Toggle("", isOn: $settings.showCountdown).labelsHidden()
                    }
                    SettingsRow("Default duration", subtitle: "Used when you activate with the hot key.") {
                        Picker("", selection: defaultDurationBinding) {
                            ForEach(CaffeineDuration.standardPresets, id: \.self) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .labelsHidden().fixedSize()
                    }
                }

                SettingsGroupLabel(text: "Battery")
                SettingsGroup {
                    BatteryThresholdRow(settings: settings)
                }
            }
            .padding(20)
        }
    }

    private var defaultDurationBinding: Binding<CaffeineDuration> {
        Binding(
            get: { settings.defaultDuration },
            set: { settings.defaultDuration = $0 }
        )
    }
}

private struct BatteryThresholdRow: View {
    @ObservedObject var settings: AppSettings
    private let provider: BatteryProvider = SystemBatteryProvider()

    var body: some View {
        let snapshot = provider.currentBattery()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Allow sleep if battery gets below").font(.system(size: 13))
                Spacer()
                Text(BatteryThresholdFormatter.label(
                    hasBattery: snapshot.hasBattery,
                    percent: settings.sleepBelowBatteryPercent
                ))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(snapshot.hasBattery ? Color.accentColor : Color.secondary)
            }
            Slider(value: percentBinding, in: 0...50, step: 5)
                .disabled(!snapshot.hasBattery)
            Text(snapshot.hasBattery
                 ? "On battery power, Open Caffein steps aside so your Mac can sleep and protect its charge."
                 : "No battery detected.")
                .font(.system(size: 11))
                .foregroundStyle(snapshot.hasBattery ? Color.secondary : Color.red)
        }
        .padding(14)
    }

    private var percentBinding: Binding<Double> {
        Binding(
            get: { Double(settings.sleepBelowBatteryPercent) },
            set: { settings.sleepBelowBatteryPercent = Int($0) }
        )
    }
}
