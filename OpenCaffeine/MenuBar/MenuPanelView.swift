import SwiftUI

/// Design variant A — the modern Liquid Glass menu-bar popover, floated in a
/// transparent panel so the `.glassEffect` card refracts the desktop. Pure view
/// layer (excluded from coverage); state lives in the injected session/settings/clock.
struct MenuPanelView: View {
    @ObservedObject var session: CaffeineSession
    @ObservedObject var settings: AppSettings
    /// Ticks only while the panel is open (see `PanelClock`).
    @ObservedObject var clock: PanelClock
    @ObservedObject var lidSleep: LidSleepController
    /// MacBooks only: shows "Stay awake with lid closed".
    var hasLid = false
    var onScreensaver: () -> Void = {}
    /// Gets the selected duration, used to start a session if none is running.
    var onDisplayOff: (CaffeineDuration) -> Void = { _ in }
    var onLidModeChange: (Bool) -> Void = { _ in }
    var onApproveLidHelper: () -> Void = {}
    var onPreferences: () -> Void = {}
    var onAbout: () -> Void = {}
    var onCustom: () -> Void = {}
    var onQuit: () -> Void = {}
    var dismiss: () -> Void = {}

    @State private var selected: CaffeineDuration = .forever

    private var active: Bool { session.state.isActive }
    private var remaining: TimeInterval? { session.state.remaining(now: clock.now) }
    private var isForever: Bool {
        if case .active(let duration, _) = session.state { return duration.timeInterval == nil }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            hero
            durationSection
            actionsRow
            keepDisplayAwakeRow
            lidRow
            footer
        }
        .padding(16)
        .frame(width: 320)
        .toggleStyle(.switch)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
        .onAppear { selected = settings.defaultDuration }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image("AppGlyph")
                .resizable().frame(width: 26, height: 26)
                .accessibilityHidden(true)  // decorative: the name is right next to it
            Text(verbatim: "Open Caffeine").font(.system(size: 15, weight: .semibold))
            Spacer()
            StatusPill(active: active)
        }
        .padding(.bottom, 14)
    }

    // MARK: Hero activate

    private var hero: some View {
        VStack(spacing: 4) {
            Button(action: toggle) {
                ZStack {
                    ProgressRing(progress: session.state.progressShown(now: clock.now), size: 120, lineWidth: 6)
                    CupBadge(active: active)
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            // The cup is an on/off control drawn as artwork: present it to
            // VoiceOver as a named switch instead of an unlabeled button.
            .accessibilityRepresentation {
                Toggle("Stay awake", isOn: Binding(get: { active }, set: { _ in toggle() }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            heroTitle
                .font(.macCountdown(26))
                .foregroundStyle(.primary)
                .padding(.top, 6)
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
    }

    private var heroTitle: Text {
        guard active else { return Text("Asleep", comment: "Menu panel: big status when no session runs") }
        let hideSeconds = settings.hideCountdownSeconds
        return Text(verbatim: CountdownFormatter.string(remaining: remaining, hideSeconds: hideSeconds))
    }

    private var subtitle: String {
        guard active else { return String(localized: "Click the cup to stay awake", comment: "Menu panel idle hint") }
        if isForever { return String(localized: "Awake — no time limit", comment: "Menu panel: Forever subtitle") }
        return String(localized: "remaining · Mac stays awake", comment: "Menu panel: subtitle under the countdown")
    }

    // MARK: Durations

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep awake for", comment: "Menu panel duration section header (shown uppercased)")
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(CaffeineDuration.standardPresets, id: \.self) { duration in
                    Chip(
                        label: duration.chipLabel,
                        spokenLabel: duration.displayName,
                        selected: isSelected(duration)
                    ) { tapChip(duration) }
                }
                let custom = String(localized: "Custom duration", comment: "VoiceOver label of the ··· chip")
                Chip(label: "···", spokenLabel: custom, selected: false) { dismiss(); onCustom() }
            }
        }
        .padding(.top, 4)
    }

    private func isSelected(_ duration: CaffeineDuration) -> Bool {
        if case .active(let current, _) = session.state { return current == duration }
        return selected == duration
    }

    private func tapChip(_ duration: CaffeineDuration) {
        if active { try? session.start(duration) } else { selected = duration }
    }

    // MARK: Actions + footer

    /// One-shot actions that blank the screen, side by side. Both close the panel;
    /// the switches below are settings that last for the session.
    private var actionsRow: some View {
        HStack(spacing: 6) {
            ActionTile(
                icon: "moon", title: "Screensaver", spokenTitle: "Start Screensaver",
                help: "Starts the screen saver."
            ) { dismiss(); onScreensaver() }
            ActionTile(
                icon: "display", title: "Display Off", spokenTitle: "Turn Display Off",
                help: "Turns the display off now. Your Mac keeps running."
            ) { dismiss(); onDisplayOff(selected) }
        }
        .padding(.top, 12)
    }

    private var keepDisplayAwakeRow: some View {
        HStack {
            Text("Keep display awake").font(.system(size: 12.5)).foregroundStyle(.secondary)
                .accessibilityHidden(true)  // the switch speaks this title itself
            Spacer()
            MacSwitch("Keep display awake", isOn: Binding(
                get: { settings.keepDisplayAwake },
                set: { settings.keepDisplayAwake = $0 }
            ))
        }
        .padding(.top, 8)
    }

    /// Keep working with the lid closed. The caption only appears when something
    /// needs the user's attention: approval, or a safety rule letting the Mac sleep.
    @ViewBuilder private var lidRow: some View {
        if hasLid {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Stay awake with lid closed").font(.system(size: 12.5)).foregroundStyle(.secondary)
                        .accessibilityHidden(true)  // the switch speaks this title itself
                    Spacer()
                    MacSwitch("Stay awake with lid closed", isOn: Binding(
                        get: { settings.stayAwakeWithLidClosed },
                        set: { onLidModeChange($0) }
                    ))
                }
                lidCaption
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var lidCaption: some View {
        if let caption = lidSleep.state.caption {
            if lidSleep.state == .needsApproval {
                Button { dismiss(); onApproveLidHelper() } label: {
                    Text(caption).font(.system(size: 11)).foregroundStyle(Color.accentColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .focusable(false)
            } else {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(lidSleep.state.captionIsWarning ? Color.orange : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 4) {
                FootButton(icon: "gearshape", title: "Preferences") { dismiss(); onPreferences() }
                FootButton(icon: "info.circle", title: "About") { dismiss(); onAbout() }
                Spacer(minLength: 0)
                FootButton(icon: "power", title: "Quit") { dismiss(); onQuit() }
            }
            .padding(.top, 10)
        }
        .padding(.top, 12)
    }

    private func toggle() {
        if active { session.stop() } else { try? session.start(selected) }
    }
}

// MARK: - Components

private struct StatusPill: View {
    let active: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
                .shadow(color: active ? .green.opacity(0.8) : .clear, radius: 2.5)
            label.font(.system(size: 11.5, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9).frame(height: 22)
        .background(.quaternary, in: Capsule())
    }

    private var label: Text {
        active ? Text("Awake", comment: "Status pill: session on") : Text("Idle", comment: "Status pill: session off")
    }
}

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat
    var lineWidth: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: size, height: size)
    }
}

/// The prototype's line-art cup glyph (ported from the design's `cup` SVG path,
/// 20×20 viewBox): a mug body + handle, drawn stroked rather than filled.
struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 20
        func pt(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint {
            CGPoint(x: unitX * scale, y: unitY * scale)
        }
        var path = Path()
        // Cup body: flat top, straight sides, rounded bottom.
        path.move(to: pt(4, 8))
        path.addLine(to: pt(15, 8))
        path.addLine(to: pt(15, 12.5))
        path.addQuadCurve(to: pt(10.5, 17), control: pt(15, 17))
        path.addLine(to: pt(8.5, 17))
        path.addQuadCurve(to: pt(4, 12.5), control: pt(4, 17))
        path.addLine(to: pt(4, 8))
        path.closeSubpath()
        // Handle loop on the right.
        path.move(to: pt(15, 9.5))
        path.addLine(to: pt(17, 9.5))
        path.addQuadCurve(to: pt(17, 13.9), control: pt(19.2, 11.7))
        path.addLine(to: pt(15, 13.9))
        // Two steam wisps above the cup.
        path.move(to: pt(7, 2.5))
        path.addCurve(to: pt(7, 5), control1: pt(6.3, 3.3), control2: pt(6.3, 4.2))
        path.move(to: pt(10.5, 2.5))
        path.addCurve(to: pt(10.5, 5), control1: pt(9.8, 3.3), control2: pt(9.8, 4.2))
        return path
    }
}

private struct CupBadge: View {
    let active: Bool
    var body: some View {
        CupShape()
            .stroke(
                active ? Color.accentColor : Color.secondary,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 46, height: 46)
            .frame(width: 90, height: 90)
            .background(
                Circle().fill(active ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.06))
            )
    }
}

private struct Chip: View {
    let label: String
    /// What VoiceOver reads: "5 min" rather than "5m", "Forever" rather than "∞".
    let spokenLabel: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .frame(maxWidth: .infinity).frame(height: Tokens.Space.chip)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? Color.accentColor : Color.primary.opacity(0.06))
                }
                .overlay {
                    if !selected {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.08))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A half-width action button. The visible title is short so two fit side by
/// side; VoiceOver reads the full `spokenTitle`.
private struct ActionTile: View {
    let icon: String
    let title: LocalizedStringKey
    let spokenTitle: LocalizedStringKey
    let help: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(title).font(.macControl).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .accessibilityLabel(spokenTitle)
    }
}

private struct FootButton: View {
    let icon: String
    let title: LocalizedStringKey
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 8).frame(height: 26)
            .foregroundStyle(hovering ? Color.primary : Color.secondary)
            .background {
                if hovering { RoundedRectangle(cornerRadius: 7).fill(.quaternary) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering = $0 }
    }
}
