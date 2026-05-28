import SwiftUI

struct DurationSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show countdown", isOn: $settings.showCountdown)
                Picker("Default duration", selection: defaultDurationBinding) {
                    ForEach(CaffeineDuration.standardPresets, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Battery") {
                BatteryThresholdRow(settings: settings)
            }
        }
        .padding(20)
        .formStyle(.grouped)
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
        VStack(alignment: .leading) {
            HStack {
                Text("Allow sleep if battery gets below:")
                Spacer()
                Text(BatteryThresholdFormatter.label(
                    hasBattery: snapshot.hasBattery,
                    percent: settings.sleepBelowBatteryPercent
                ))
                .foregroundStyle(.secondary)
            }
            Slider(value: percentBinding, in: 0...50, step: 5)
                .disabled(!snapshot.hasBattery)
            if !snapshot.hasBattery {
                Text("No battery detected").foregroundStyle(.red)
            }
        }
    }

    private var percentBinding: Binding<Double> {
        Binding(
            get: { Double(settings.sleepBelowBatteryPercent) },
            set: { settings.sleepBelowBatteryPercent = Int($0) }
        )
    }
}
