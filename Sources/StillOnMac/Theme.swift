import AppKit
import SwiftUI

/// Colours from the StillOnMac design canvas.
enum Theme {
    static let amber = Color(hex: 0xF2A33A)
    static let onAmber = Color(hex: 0x1D1508)
    static let amberTile = Color(hex: 0x3B2E1B)

    static let background = Color(hex: 0x242228)
    static let card = Color(hex: 0x2D2B33)
    static let cardBorder = Color(hex: 0x45414D)
    static let divider = Color(hex: 0x3A3740)
    static let iconTile = Color(hex: 0x3A3742)
    static let switchOff = Color(hex: 0x4A4751)
    static let knobOff = Color(hex: 0xD9D6DE)

    static let text = Color(hex: 0xF2F0EB)
    static let secondary = Color(hex: 0xA9A5B0)
    static let chipText = Color(hex: 0xCFCBD6)
    static let good = Color(hex: 0x7DDC9A)

    static let warnBackground = Color(hex: 0x3A2A14)
    static let warnBorder = Color(hex: 0x6B4A1C)
    static let warnText = Color(hex: 0xFFD08A)
    static let warnBody = Color(hex: 0xF1DCC0)

    /// Menu bar icon tint: bright amber on a dark menu bar, deeper amber on a light one.
    static let menuBarAmber = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(hex: 0xF2A33A)
            : NSColor(hex: 0xB86E0A)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
