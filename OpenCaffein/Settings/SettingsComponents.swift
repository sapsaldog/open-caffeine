import SwiftUI

// Tahoe System-Settings layout primitives, mirroring the design's
// GroupLabel / Group / Row and the `.mac-seg` segmented control. View shells —
// excluded from the coverage gate.

/// Uppercase, secondary group caption above a settings group.
struct SettingsGroupLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

/// White rounded container holding stacked `SettingsRow`s.
struct SettingsGroup<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
    }
}

/// A grouped row: title (+ optional subtitle) on the left, a trailing control.
struct SettingsRow<Control: View>: View {
    private let title: String
    private let subtitle: String?
    private let first: Bool
    private let control: Control

    init(_ title: String, subtitle: String? = nil, first: Bool = false, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.first = first
        self.control = control()
    }

    var body: some View {
        VStack(spacing: 0) {
            if !first { Divider().padding(.leading, 14) }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                control
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
        }
    }
}

/// macOS-style segmented control (design `.mac-seg`): subtle track, the selected
/// segment lifts onto a control-colored chip. Each segment's content is supplied
/// by the caller and told whether it is selected.
struct MacSegmentedControl<Value: Hashable, Segment: View>: View {
    @Binding var selection: Value
    let values: [Value]
    private let segment: (Value, Bool) -> Segment

    init(
        selection: Binding<Value>,
        values: [Value],
        @ViewBuilder segment: @escaping (Value, Bool) -> Segment
    ) {
        self._selection = selection
        self.values = values
        self.segment = segment
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(values, id: \.self) { value in
                let selected = value == selection
                Button { selection = value } label: {
                    segment(value, selected)
                        .frame(height: 26)
                        .padding(.horizontal, 9)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.14), radius: 1, y: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .fixedSize()
    }
}
