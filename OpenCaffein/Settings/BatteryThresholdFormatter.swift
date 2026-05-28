import Foundation

/// Formats the battery-threshold label shown in Duration settings. Extracted from
/// the view so the three display states are unit-testable.
enum BatteryThresholdFormatter {
    static func label(hasBattery: Bool, percent: Int) -> String {
        guard hasBattery else { return "—" }
        return percent == 0 ? "Disabled" : "\(percent)%"
    }
}
