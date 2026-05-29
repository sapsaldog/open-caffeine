import SwiftUI

/// The three monochrome menu-bar coffee glyphs (Coffee Type 1/2/3 = mug /
/// to-go / cup & saucer), ported from the design's glyph sheet. Drawn with a
/// `Canvas` (fills + strokes), rendered to a template image for the status item
/// and shown in the picker. View shell — excluded from the coverage gate.
struct CoffeeGlyph: View {
    let type: MenuBarIconStyle
    var color: Color = .primary
    var zoom: CGFloat = 1.0

    var body: some View {
        Canvas { context, size in
            var ctx = context
            let side = min(size.width, size.height) * zoom
            ctx.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            let scale = side / 20
            switch type {
            case .coffeeType1: drawMug(ctx, scale)
            case .coffeeType2: drawToGo(ctx, scale)
            case .coffeeType3: drawCupAndSaucer(ctx, scale)
            }
        }
    }

    private func stroke(_ context: GraphicsContext, _ path: Path, _ width: CGFloat, _ scale: CGFloat) {
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawMug(_ context: GraphicsContext, _ scale: CGFloat) {
        func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint { CGPoint(x: unitX * scale, y: unitY * scale) }
        var body = Path()
        body.move(to: point(3.6, 7.4))
        body.addLine(to: point(12.4, 7.4))
        body.addLine(to: point(12.4, 12.0))
        body.addQuadCurve(to: point(8.0, 16.4), control: point(12.4, 16.4))
        body.addQuadCurve(to: point(3.6, 12.0), control: point(3.6, 16.4))
        body.closeSubpath()
        context.fill(body, with: .color(color))

        var handle = Path()
        handle.move(to: point(12.4, 8.6))
        handle.addLine(to: point(14.3, 8.6))
        handle.addQuadCurve(to: point(14.3, 13.2), control: point(16.9, 10.9))
        handle.addLine(to: point(12.4, 13.2))
        stroke(context, handle, 1.5, scale)

        var steam = Path()
        for originX in [CGFloat(5.6), 8.0, 10.4] {
            steam.move(to: point(originX, 5.4))
            steam.addQuadCurve(to: point(originX, 3.4), control: point(originX - 1, 4.4))
        }
        stroke(context, steam, 1.4, scale)
    }

    private func drawToGo(_ context: GraphicsContext, _ scale: CGFloat) {
        func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint { CGPoint(x: unitX * scale, y: unitY * scale) }
        var lid = Path()
        lid.move(to: point(5, 7.2))
        lid.addLine(to: point(15, 7.2))
        lid.addLine(to: point(14.5, 8.9))
        lid.addLine(to: point(5.5, 8.9))
        lid.closeSubpath()
        context.fill(lid, with: .color(color))

        var body = Path()
        body.move(to: point(6, 9.4))
        body.addLine(to: point(14, 9.4))
        body.addLine(to: point(13, 16.5))
        body.addQuadCurve(to: point(12.1, 17.3), control: point(13, 17.3))
        body.addLine(to: point(7.9, 17.3))
        body.addQuadCurve(to: point(7, 16.5), control: point(7, 17.3))
        body.closeSubpath()
        context.fill(body, with: .color(color))

        let tabRect = CGRect(x: 8.4 * scale, y: 4.6 * scale, width: 3.2 * scale, height: 1.8 * scale)
        context.fill(Path(roundedRect: tabRect, cornerRadius: 0.9 * scale), with: .color(color))

        var steam = Path()
        steam.move(to: point(7.4, 3.6))
        steam.addQuadCurve(to: point(7.4, 2.0), control: point(6.6, 2.8))
        steam.move(to: point(12.6, 3.6))
        steam.addQuadCurve(to: point(12.6, 2.0), control: point(11.8, 2.8))
        stroke(context, steam, 1.3, scale)
    }

    private func drawCupAndSaucer(_ context: GraphicsContext, _ scale: CGFloat) {
        func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint { CGPoint(x: unitX * scale, y: unitY * scale) }
        var cup = Path()
        cup.move(to: point(4.4, 7.2))
        cup.addLine(to: point(12.0, 7.2))
        cup.addLine(to: point(12.0, 10.0))
        cup.addQuadCurve(to: point(8.2, 13.8), control: point(12.0, 13.8))
        cup.addQuadCurve(to: point(4.4, 10.0), control: point(4.4, 13.8))
        cup.closeSubpath()
        context.fill(cup, with: .color(color))

        let saucerRect = CGRect(x: 3.2 * scale, y: 15.0 * scale, width: 12.6 * scale, height: 1.5 * scale)
        context.fill(Path(roundedRect: saucerRect, cornerRadius: 0.75 * scale), with: .color(color))

        var handle = Path()
        handle.move(to: point(12.0, 8.2))
        handle.addLine(to: point(13.7, 8.2))
        handle.addQuadCurve(to: point(13.7, 11.8), control: point(16.0, 10.0))
        handle.addLine(to: point(12.0, 11.8))
        stroke(context, handle, 1.4, scale)

        var steam = Path()
        steam.move(to: point(6.6, 5.6))
        steam.addQuadCurve(to: point(6.6, 3.6), control: point(5.7, 4.6))
        steam.move(to: point(9.4, 5.6))
        steam.addQuadCurve(to: point(9.4, 3.6), control: point(8.5, 4.6))
        stroke(context, steam, 1.3, scale)
    }
}

/// Renders a coffee glyph to a template `NSImage` for the menu-bar status item.
@MainActor
enum CoffeeGlyphRenderer {
    static func image(_ type: MenuBarIconStyle, pointSize: CGFloat = 18) -> NSImage {
        let renderer = ImageRenderer(
            content: CoffeeGlyph(type: type, color: .black, zoom: 1.18).frame(width: pointSize, height: pointSize)
        )
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}

/// Segmented picker of the three coffee glyphs, bound to the menu-bar icon style.
struct CoffeeGlyphPicker: View {
    @Binding var selection: MenuBarIconStyle
    var glyphSize: CGFloat = 22

    var body: some View {
        MacSegmentedControl(selection: $selection, values: MenuBarIconStyle.allCases) { style, selected in
            CoffeeGlyph(type: style, color: selected ? .accentColor : .secondary)
                .frame(width: glyphSize, height: glyphSize)
        }
    }
}
