#!/usr/bin/env swift

import AppKit

private let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let assetURL = rootURL
    .appendingPathComponent("OpenCaffein")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Assets.xcassets")

private let canvas: CGFloat = 22
private let ink = CGColor(gray: 0, alpha: 1)

private enum IconStyle {
    case mug
    case bean
    case tumbler
}

private struct IconOutput {
    let style: IconStyle
    let isActive: Bool
    let folder: String
    let filename: String
}

private let outputs = [
    IconOutput(style: .mug, isActive: false, folder: "MenuBarIcon.imageset", filename: "coffee.pdf"),
    IconOutput(style: .mug, isActive: true, folder: "MenuBarIconActive.imageset", filename: "coffee_active.pdf"),
    IconOutput(style: .bean, isActive: false, folder: "MenuBarIcon2.imageset", filename: "coffee2.pdf"),
    IconOutput(style: .bean, isActive: true, folder: "MenuBarIcon2Active.imageset", filename: "coffee2_active.pdf"),
    IconOutput(style: .tumbler, isActive: false, folder: "MenuBarIcon3.imageset", filename: "coffee3.pdf"),
    IconOutput(style: .tumbler, isActive: true, folder: "MenuBarIcon3Active.imageset", filename: "coffee3_active.pdf")
]

private func withPDFContext(at url: URL, draw: (CGContext) -> Void) {
    var mediaBox = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    guard
        let consumer = CGDataConsumer(url: url as CFURL),
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else {
        fatalError("Could not create PDF context for \(url.path)")
    }

    context.beginPDFPage(nil)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(ink)
    context.setFillColor(ink)
    draw(context)
    context.endPDFPage()
    context.closePDF()
}

private func stroke(_ context: CGContext, _ path: CGPath, width: CGFloat) {
    context.saveGState()
    context.setLineWidth(width)
    context.addPath(path)
    context.strokePath()
    context.restoreGState()
}

private func fill(_ context: CGContext, _ path: CGPath) {
    context.saveGState()
    context.addPath(path)
    context.fillPath()
    context.restoreGState()
}

private func line(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard let firstPoint = points.first else { return path }
    path.move(to: firstPoint)
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    return path
}

private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
    return path
}

private func ellipse(_ rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.addEllipse(in: rect)
    return path
}

private func boltPath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard let firstPoint = points.first else { return path }
    path.move(to: firstPoint)
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

private func drawMug(_ context: CGContext, isActive: Bool) {
    stroke(context, ellipse(CGRect(x: 3.35, y: 11.7, width: 13.6, height: 3.3)), width: 1.45)
    stroke(context, roundedRect(CGRect(x: 4.45, y: 4.65, width: 11.1, height: 8.35), radius: 2.45), width: 1.55)

    let handle = CGMutablePath()
    handle.move(to: CGPoint(x: 15.25, y: 11.2))
    handle.addCurve(
        to: CGPoint(x: 15.15, y: 6.5),
        control1: CGPoint(x: 19.15, y: 11.3),
        control2: CGPoint(x: 19.1, y: 6.3)
    )
    stroke(context, handle, width: 1.55)

    let saucer = CGMutablePath()
    saucer.move(to: CGPoint(x: 5.35, y: 3.45))
    saucer.addCurve(
        to: CGPoint(x: 15.65, y: 3.45),
        control1: CGPoint(x: 8.0, y: 2.65),
        control2: CGPoint(x: 13.0, y: 2.65)
    )
    stroke(context, saucer, width: 1.25)

    let leftSteam = CGMutablePath()
    leftSteam.move(to: CGPoint(x: 7.55, y: 15.0))
    leftSteam.addCurve(
        to: CGPoint(x: 8.35, y: 19.25),
        control1: CGPoint(x: 5.85, y: 16.45),
        control2: CGPoint(x: 9.45, y: 17.25)
    )
    stroke(context, leftSteam, width: 1.45)

    let rightSteam = CGMutablePath()
    rightSteam.move(to: CGPoint(x: 11.85, y: 15.0))
    rightSteam.addCurve(
        to: CGPoint(x: 12.85, y: 19.6),
        control1: CGPoint(x: 10.05, y: 16.65),
        control2: CGPoint(x: 14.25, y: 17.75)
    )
    stroke(context, rightSteam, width: 1.45)

    guard isActive else { return }

    fill(context, boltPath([
        CGPoint(x: 10.95, y: 11.05),
        CGPoint(x: 8.85, y: 7.85),
        CGPoint(x: 10.65, y: 8.0),
        CGPoint(x: 9.4, y: 5.5),
        CGPoint(x: 13.25, y: 9.25),
        CGPoint(x: 11.35, y: 9.08)
    ]))
}

private func drawBean(_ context: CGContext, isActive: Bool) {
    context.saveGState()
    context.translateBy(x: 10.45, y: 10.65)
    context.rotate(by: -0.58)

    let bean = CGMutablePath()
    bean.move(to: CGPoint(x: 0, y: 7.1))
    bean.addCurve(
        to: CGPoint(x: 6.15, y: 0.15),
        control1: CGPoint(x: 4.2, y: 6.85),
        control2: CGPoint(x: 7.15, y: 3.7)
    )
    bean.addCurve(
        to: CGPoint(x: 0.25, y: -7.15),
        control1: CGPoint(x: 5.7, y: -4.25),
        control2: CGPoint(x: 2.25, y: -7.25)
    )
    bean.addCurve(
        to: CGPoint(x: -6.15, y: -0.2),
        control1: CGPoint(x: -4.15, y: -6.95),
        control2: CGPoint(x: -7.2, y: -3.85)
    )
    bean.addCurve(
        to: CGPoint(x: 0, y: 7.1),
        control1: CGPoint(x: -5.7, y: 4.2),
        control2: CGPoint(x: -2.1, y: 7.35)
    )
    stroke(context, bean, width: 1.6)

    let groove = CGMutablePath()
    groove.move(to: CGPoint(x: 0.35, y: 5.45))
    groove.addCurve(
        to: CGPoint(x: -0.2, y: -5.45),
        control1: CGPoint(x: -2.35, y: 2.15),
        control2: CGPoint(x: 2.3, y: -2.05)
    )
    stroke(context, groove, width: 1.35)
    context.restoreGState()

    guard isActive else { return }

    fill(context, boltPath([
        CGPoint(x: 16.15, y: 18.95),
        CGPoint(x: 13.8, y: 15.15),
        CGPoint(x: 15.55, y: 15.25),
        CGPoint(x: 14.1, y: 11.75),
        CGPoint(x: 18.25, y: 16.35),
        CGPoint(x: 16.25, y: 16.1)
    ]))
}

private func drawTumbler(_ context: CGContext, isActive: Bool) {
    let straw = CGMutablePath()
    straw.move(to: CGPoint(x: 10.7, y: 15.45))
    straw.addLine(to: CGPoint(x: 11.35, y: 19.05))
    straw.addLine(to: CGPoint(x: 13.15, y: 19.75))
    stroke(context, straw, width: 1.35)

    stroke(context, roundedRect(CGRect(x: 4.7, y: 12.7, width: 12.6, height: 2.6), radius: 1.15), width: 1.45)

    let cup = CGMutablePath()
    cup.move(to: CGPoint(x: 6.15, y: 12.55))
    cup.addLine(to: CGPoint(x: 15.85, y: 12.55))
    cup.addLine(to: CGPoint(x: 14.45, y: 4.1))
    cup.addQuadCurve(to: CGPoint(x: 7.55, y: 4.1), control: CGPoint(x: 11.0, y: 3.15))
    cup.closeSubpath()
    stroke(context, cup, width: 1.55)

    stroke(context, roundedRect(CGRect(x: 7.25, y: 7.2, width: 7.5, height: 3.0), radius: 0.95), width: 1.25)

    guard isActive else { return }

    fill(context, boltPath([
        CGPoint(x: 11.15, y: 10.15),
        CGPoint(x: 9.15, y: 7.15),
        CGPoint(x: 10.78, y: 7.25),
        CGPoint(x: 9.75, y: 5.25),
        CGPoint(x: 13.35, y: 8.8),
        CGPoint(x: 11.55, y: 8.6)
    ]))
}

for output in outputs {
    let folderURL = assetURL.appendingPathComponent(output.folder)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    let fileURL = folderURL.appendingPathComponent(output.filename)

    withPDFContext(at: fileURL) { context in
        switch output.style {
        case .mug:
            drawMug(context, isActive: output.isActive)
        case .bean:
            drawBean(context, isActive: output.isActive)
        case .tumbler:
            drawTumbler(context, isActive: output.isActive)
        }
    }
}

print("Generated \(outputs.count) menu bar icon PDFs in \(assetURL.path)")
