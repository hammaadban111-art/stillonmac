// Draws StillOnMac's app icon and the DMG window background.
//   swift scripts/make-art.swift <outDir>
// Writes <outDir>/AppIcon.iconset/*.png, dmg-background.png and dmg-background@2x.png.
import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift make-art.swift <outDir>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = outDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Draws into a bitmap of exactly width×height pixels (1 point = 1 pixel) and saves it as PNG.
func render(width: Int, height: Int, to url: URL, draw: () -> Void) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw NSError(domain: "make-art", code: 1) }
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make-art", code: 2)
    }
    try png.write(to: url)
}

// MARK: App icon

let amber = color(0xF2A33A)

func drawIcon(size s: CGFloat) {
    // Apple's icon grid: an 824 pt body on a 1024 pt canvas.
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = body.width * 0.225
    let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.set()
    color(0x242228).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    shape.lineWidth = max(1, s / 400)
    color(0x3A3740).setStroke()
    shape.stroke()

    let config = NSImage.SymbolConfiguration(pointSize: body.width * 0.44, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [amber]))
    guard let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    else { return }
    let size = symbol.size
    symbol.draw(in: NSRect(
        x: body.midX - size.width / 2,
        y: body.midY - size.height / 2,
        width: size.width,
        height: size.height
    ))
}

let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for icon in iconSizes {
    try render(width: icon.pixels, height: icon.pixels, to: iconset.appendingPathComponent("\(icon.name).png")) {
        drawIcon(size: CGFloat(icon.pixels))
    }
}

// MARK: DMG background (600×400 window; Finder icons at (150, 200) and (450, 200))

func drawBackground(scale k: CGFloat) {
    let width: CGFloat = 600
    let height: CGFloat = 400
    color(0xF4F1EA).setFill()
    NSRect(x: 0, y: 0, width: width * k, height: height * k).fill()

    /// Finder coordinates (origin top-left) → bitmap coordinates.
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x * k, y: (height - y) * k)
    }

    func centeredText(_ text: String, font: NSFont, color textColor: NSColor, top: CGFloat) {
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
        let size = string.size()
        string.draw(at: NSPoint(x: (width * k - size.width) / 2, y: (height - top) * k - size.height))
    }

    centeredText("StillOnMac", font: .systemFont(ofSize: 26 * k, weight: .bold), color: color(0x1F1D24), top: 36)
    centeredText("Drag the cup into Applications", font: .systemFont(ofSize: 14 * k), color: color(0x5B5664), top: 74)

    let arrow = NSBezierPath()
    arrow.move(to: point(234, 210))
    arrow.curve(to: point(362, 206), controlPoint1: point(268, 178), controlPoint2: point(328, 178))
    arrow.move(to: point(346, 208))
    arrow.line(to: point(362, 206))
    arrow.line(to: point(358, 190))
    arrow.lineWidth = 5 * k
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    color(0xE08A1E).setStroke()
    arrow.stroke()
}

try render(width: 600, height: 400, to: outDir.appendingPathComponent("dmg-background.png")) {
    drawBackground(scale: 1)
}
try render(width: 1200, height: 800, to: outDir.appendingPathComponent("dmg-background@2x.png")) {
    drawBackground(scale: 2)
}

print("Art written to \(outDir.path)")
