import SwiftUI

/// One 1–4 face from the mockup, drawn from its exact 20×20 SVG geometry
/// (outer circle r8.3, stroke 1.6, round caps). Monochrome: selected uses
/// `.primary` over a faint chip, unselected `.secondary`.
struct RatingFace: View {
    let value: Int
    let isSelected: Bool

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 20.0
            context.scaleBy(x: unit, y: unit)
            let shading = GraphicsContext.Shading.color(isSelected ? .primary : .secondary)
            let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

            context.stroke(
                Path(ellipseIn: CGRect(x: 1.7, y: 1.7, width: 16.6, height: 16.6)),
                with: shading, style: stroke)
            drawEyes(context, shading: shading, stroke: stroke)
            if value == 1 {
                context.stroke(brow(from: 5.7, control: 7.2, to: 8.6), with: shading, style: stroke)
                context.stroke(brow(from: 11.4, control: 12.8, to: 14.3), with: shading, style: stroke)
            }
            context.stroke(mouth(), with: shading, style: stroke)
        }
        .frame(width: 34, height: 34)
        .padding(5)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06))
            }
        }
        .contentShape(Rectangle())
    }

    private func drawEyes(_ context: GraphicsContext,
                          shading: GraphicsContext.Shading, stroke: StrokeStyle) {
        if value == 4 {
            context.stroke(eyeArc(from: 5.9, control: 7.2, to: 8.5), with: shading, style: stroke)
            context.stroke(eyeArc(from: 11.5, control: 12.8, to: 14.1), with: shading, style: stroke)
            return
        }
        let eyeY: CGFloat = value == 1 ? 8.6 : (value == 2 ? 8.4 : 8.2)
        for centerX: CGFloat in [7.2, 12.8] {
            let dot = Path(ellipseIn: CGRect(x: centerX - 0.62, y: eyeY - 0.62,
                                             width: 1.24, height: 1.24))
            context.fill(dot, with: shading)
        }
    }

    private func eyeArc(from startX: CGFloat, control: CGFloat, to endX: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: startX, y: 8.8))
        path.addQuadCurve(to: CGPoint(x: endX, y: 8.8), control: CGPoint(x: control, y: 7.2))
        return path
    }

    private func brow(from startX: CGFloat, control: CGFloat, to endX: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: startX, y: 6.9))
        path.addQuadCurve(to: CGPoint(x: endX, y: 6.9), control: CGPoint(x: control, y: 6.1))
        return path
    }

    private func mouth() -> Path {
        var path = Path()
        switch value {
        case 1:
            path.move(to: CGPoint(x: 6.6, y: 13.7))
            path.addQuadCurve(to: CGPoint(x: 13.4, y: 13.7), control: CGPoint(x: 10, y: 11.2))
        case 2:
            path.move(to: CGPoint(x: 6.9, y: 12.4))
            path.addLine(to: CGPoint(x: 13.1, y: 12.4))
        case 3:
            path.move(to: CGPoint(x: 6.7, y: 11.7))
            path.addQuadCurve(to: CGPoint(x: 13.3, y: 11.7), control: CGPoint(x: 10, y: 14.1))
        default:
            path.move(to: CGPoint(x: 6, y: 11.3))
            path.addQuadCurve(to: CGPoint(x: 14, y: 11.3), control: CGPoint(x: 10, y: 15.3))
        }
        return path
    }
}

/// The row of four faces. `onSelect` toggles via the view model.
struct FaceRatingRow: View {
    let selection: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { value in
                Button { onSelect(value) } label: {
                    RatingFace(value: value, isSelected: selection == value)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
