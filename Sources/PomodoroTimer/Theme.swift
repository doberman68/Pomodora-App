import AppKit
import SwiftUI

/// An sRGB color that can be persisted and mixed.
struct RGB: Equatable, Codable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init?(nsColor: NSColor) {
        guard let c = nsColor.usingColorSpace(.sRGB) else { return nil }
        self.init(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    }

    static let white = RGB(1, 1, 1)
    static let black = RGB(0, 0, 0)

    var color: Color { Color(red: r, green: g, blue: b) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }

    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    func mixed(with other: RGB, _ t: Double) -> RGB {
        RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    func lighter(_ t: Double) -> RGB { mixed(with: .white, t) }
    func darker(_ t: Double) -> RGB { mixed(with: .black, t) }
}

/// Clock colors: the frame (bezel, knob, side tab) and the remaining-time disk.
/// Shading is derived from these two base colors.
struct Theme: Equatable, Codable {
    var frame: RGB
    var disk: RGB

    var bezelTop: Color { frame.lighter(0.12).color }
    var bezelBottom: Color { frame.darker(0.12).color }
    var diskTop: Color { disk.lighter(0.12).color }
    var diskBottom: Color { disk.darker(0.08).color }
    var knobLight: Color { frame.lighter(0.4).color }
    var knobDark: Color { frame.color }
    /// Readout text on the white face: darken light frames more so it stays legible.
    var label: Color { frame.darker(frame.luminance > 0.6 ? 0.5 : 0.3).color }

    static let slate = Theme(frame: RGB(0.535, 0.61, 0.695), disk: RGB(0.21, 0.21, 0.37))

    static let presets: [(name: String, theme: Theme)] = [
        ("Slate & Navy", slate),
        ("Classic Red", Theme(frame: RGB(0.78, 0.79, 0.81), disk: RGB(0.85, 0.13, 0.15))),
        ("Ocean", Theme(frame: RGB(0.45, 0.66, 0.84), disk: RGB(0.10, 0.35, 0.70))),
        ("Mint", Theme(frame: RGB(0.55, 0.78, 0.70), disk: RGB(0.05, 0.50, 0.45))),
        ("Lavender", Theme(frame: RGB(0.68, 0.62, 0.82), disk: RGB(0.40, 0.22, 0.62))),
        ("Blush", Theme(frame: RGB(0.93, 0.70, 0.72), disk: RGB(0.90, 0.36, 0.33))),
        ("Sunshine", Theme(frame: RGB(0.95, 0.83, 0.45), disk: RGB(0.93, 0.50, 0.10))),
        ("Charcoal & Orange", Theme(frame: RGB(0.25, 0.26, 0.28), disk: RGB(0.96, 0.45, 0.12))),
    ]

    /// Small menu icon: frame, white face, and a disk dot.
    var swatch: NSImage {
        let frameColor = frame.nsColor
        let diskColor = disk.nsColor
        return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            frameColor.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4).fill()
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), xRadius: 2, yRadius: 2).fill()
            diskColor.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 4.5, dy: 4.5)).fill()
            return true
        }
    }
}
