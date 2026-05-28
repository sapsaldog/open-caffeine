#!/usr/bin/env swift

import AppKit

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconURL = rootURL
    .appendingPathComponent("OpenCaffein")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

try FileManager.default.createDirectory(at: appIconURL, withIntermediateDirectories: true)

let baseSize = 1024
let canvas = NSSize(width: baseSize, height: baseSize)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func drawGradient(in rect: CGRect, colors: [NSColor], locations: [CGFloat], start: CGPoint, end: CGPoint) {
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: locations
    ) else {
        return
    }

    NSGraphicsContext.current?.cgContext.drawLinearGradient(gradient, start: start, end: end, options: [])
}

func makePolygon(_ points: [CGPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    guard let firstPoint = points.first else { return path }
    path.move(to: firstPoint)
    for point in points.dropFirst() {
        path.line(to: point)
    }
    path.close()
    return path
}

func strokePath(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

let icon = NSImage(size: canvas)
icon.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Could not create graphics context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.setFill()
CGRect(origin: .zero, size: canvas).fill()

let iconRect = CGRect(x: 56, y: 56, width: 912, height: 912)
let outerShape = NSBezierPath(roundedRect: iconRect, xRadius: 212, yRadius: 212)

let outerShadow = NSShadow()
outerShadow.shadowColor = color(0x06101c, alpha: 0.45)
outerShadow.shadowBlurRadius = 44
outerShadow.shadowOffset = NSSize(width: 0, height: -22)
outerShadow.set()

color(0x101d31).setFill()
outerShape.fill()
NSShadow().set()

context.saveGState()
outerShape.addClip()
drawGradient(
    in: iconRect,
    colors: [color(0x143342), color(0x26304b), color(0x4b2245)],
    locations: [0, 0.56, 1],
    start: CGPoint(x: 116, y: 916),
    end: CGPoint(x: 884, y: 108)
)

let warmGlow = NSBezierPath(ovalIn: CGRect(x: 64, y: 60, width: 530, height: 440))
color(0xf6a03d, alpha: 0.20).setFill()
warmGlow.fill()

let coolGlow = NSBezierPath(ovalIn: CGRect(x: 556, y: 606, width: 360, height: 280))
color(0x15d6c5, alpha: 0.16).setFill()
coolGlow.fill()

let topSheen = NSBezierPath(roundedRect: CGRect(x: 88, y: 672, width: 848, height: 248), xRadius: 168, yRadius: 168)
color(0xffffff, alpha: 0.055).setFill()
topSheen.fill()
context.restoreGState()

let border = NSBezierPath(roundedRect: iconRect.insetBy(dx: 10, dy: 10), xRadius: 200, yRadius: 200)
border.lineWidth = 7
color(0xffffff, alpha: 0.22).setStroke()
border.stroke()

let steamShadow = NSShadow()
steamShadow.shadowColor = color(0x07111d, alpha: 0.32)
steamShadow.shadowBlurRadius = 18
steamShadow.shadowOffset = NSSize(width: 0, height: -8)
steamShadow.set()

let steamLeft = NSBezierPath()
steamLeft.move(to: CGPoint(x: 352, y: 676))
steamLeft.curve(to: CGPoint(x: 384, y: 818), controlPoint1: CGPoint(x: 302, y: 730), controlPoint2: CGPoint(x: 430, y: 756))
strokePath(steamLeft, color: color(0xf8ead3, alpha: 0.90), width: 36)

let steamMiddle = NSBezierPath()
steamMiddle.move(to: CGPoint(x: 502, y: 662))
steamMiddle.curve(to: CGPoint(x: 546, y: 852), controlPoint1: CGPoint(x: 434, y: 734), controlPoint2: CGPoint(x: 608, y: 768))
strokePath(steamMiddle, color: color(0x5ff0df, alpha: 0.95), width: 40)

let steamRight = NSBezierPath()
steamRight.move(to: CGPoint(x: 650, y: 674))
steamRight.curve(to: CGPoint(x: 680, y: 810), controlPoint1: CGPoint(x: 610, y: 728), controlPoint2: CGPoint(x: 724, y: 756))
strokePath(steamRight, color: color(0xf8ead3, alpha: 0.82), width: 32)

NSShadow().set()

let saucerShadow = NSShadow()
saucerShadow.shadowColor = color(0x050b12, alpha: 0.42)
saucerShadow.shadowBlurRadius = 30
saucerShadow.shadowOffset = NSSize(width: 0, height: -12)
saucerShadow.set()

let saucer = NSBezierPath(ovalIn: CGRect(x: 272, y: 250, width: 486, height: 88))
color(0xd88a33, alpha: 0.42).setFill()
saucer.fill()

NSShadow().set()

let handleBack = NSBezierPath()
handleBack.move(to: CGPoint(x: 668, y: 520))
handleBack.curve(
    to: CGPoint(x: 684, y: 370),
    controlPoint1: CGPoint(x: 832, y: 560),
    controlPoint2: CGPoint(x: 826, y: 338)
)
strokePath(handleBack, color: color(0xf5d99b), width: 96)
strokePath(handleBack, color: color(0x1c2d42), width: 42)

let cupShadow = NSShadow()
cupShadow.shadowColor = color(0x06101a, alpha: 0.38)
cupShadow.shadowBlurRadius = 32
cupShadow.shadowOffset = NSSize(width: 0, height: -14)
cupShadow.set()

let cupBody = NSBezierPath(roundedRect: CGRect(x: 236, y: 302, width: 500, height: 288), xRadius: 78, yRadius: 78)
color(0xf8dca3).setFill()
cupBody.fill()

NSShadow().set()

context.saveGState()
cupBody.addClip()
drawGradient(
    in: CGRect(x: 236, y: 302, width: 500, height: 288),
    colors: [color(0xfff0c6), color(0xf0bc61), color(0xc96e2d)],
    locations: [0, 0.56, 1],
    start: CGPoint(x: 270, y: 594),
    end: CGPoint(x: 690, y: 296)
)
let cupHighlight = NSBezierPath(roundedRect: CGRect(x: 292, y: 490, width: 168, height: 58), xRadius: 28, yRadius: 28)
color(0xffffff, alpha: 0.30).setFill()
cupHighlight.fill()
context.restoreGState()

let cupRim = NSBezierPath(ovalIn: CGRect(x: 252, y: 548, width: 468, height: 110))
color(0xffecc2).setFill()
cupRim.fill()

let coffee = NSBezierPath(ovalIn: CGRect(x: 296, y: 574, width: 380, height: 60))
color(0x281611).setFill()
coffee.fill()

let coffeeShine = NSBezierPath(ovalIn: CGRect(x: 386, y: 592, width: 112, height: 20))
color(0xfff1c9, alpha: 0.22).setFill()
coffeeShine.fill()

let boltShadow = NSShadow()
boltShadow.shadowColor = color(0x5a2d16, alpha: 0.28)
boltShadow.shadowBlurRadius = 9
boltShadow.shadowOffset = NSSize(width: 0, height: -5)
boltShadow.set()

let bolt = makePolygon([
    CGPoint(x: 502, y: 544),
    CGPoint(x: 406, y: 422),
    CGPoint(x: 486, y: 434),
    CGPoint(x: 452, y: 338),
    CGPoint(x: 604, y: 482),
    CGPoint(x: 526, y: 466)
])
color(0x22d8c8).setFill()
bolt.fill()

NSShadow().set()

let boltInset = makePolygon([
    CGPoint(x: 503, y: 510),
    CGPoint(x: 461, y: 455),
    CGPoint(x: 514, y: 462),
    CGPoint(x: 491, y: 410),
    CGPoint(x: 548, y: 466),
    CGPoint(x: 507, y: 458)
])
color(0xdffef9, alpha: 0.50).setFill()
boltInset.fill()

icon.unlockFocus()

guard
    let tiffData = icon.tiffRepresentation,
    let sourceRep = NSBitmapImageRep(data: tiffData)
else {
    fatalError("Could not create source bitmap")
}

let outputs: [(size: String, scale: String, pixels: Int, filename: String)] = [
    ("16x16", "1x", 16, "app-icon-16.png"),
    ("16x16", "2x", 32, "app-icon-16@2x.png"),
    ("32x32", "1x", 32, "app-icon-32.png"),
    ("32x32", "2x", 64, "app-icon-32@2x.png"),
    ("128x128", "1x", 128, "app-icon-128.png"),
    ("128x128", "2x", 256, "app-icon-128@2x.png"),
    ("256x256", "1x", 256, "app-icon-256.png"),
    ("256x256", "2x", 512, "app-icon-256@2x.png"),
    ("512x512", "1x", 512, "app-icon-512.png"),
    ("512x512", "2x", 1024, "app-icon-512@2x.png")
]

func writePNG(pixels: Int, filename: String) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create \(pixels)x\(pixels) bitmap")
    }

    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceRep.draw(
        in: CGRect(x: 0, y: 0, width: pixels, height: pixels),
        from: CGRect(x: 0, y: 0, width: baseSize, height: baseSize),
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(filename)")
    }

    try png.write(to: appIconURL.appendingPathComponent(filename), options: .atomic)
}

for output in outputs {
    try writePNG(pixels: output.pixels, filename: output.filename)
}

let images = outputs.map { output in
    """
        {
          "filename" : "\(output.filename)",
          "idiom" : "mac",
          "scale" : "\(output.scale)",
          "size" : "\(output.size)"
        }
    """
}.joined(separator: ",\n")

let contents = """
{
  "images" : [
\(images)
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""

try contents.write(to: appIconURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Generated \(outputs.count) app icon images in \(appIconURL.path)")
