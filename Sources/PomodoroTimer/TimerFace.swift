import SwiftUI

/// Fixed colors. Frame and disk colors come from `Theme`.
enum Palette {
    static let face = Color(red: 0.975, green: 0.978, blue: 0.99)
    static let faceShade = Color(red: 0.92, green: 0.925, blue: 0.945)
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.09)
}

/// Dial math. Minutes run counter-clockwise from 12 o'clock, like the physical Time Timer.
enum DialGeometry {
    static func point(minutes: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = minutes / 60 * 2 * Double.pi
        return CGPoint(x: center.x - radius * CGFloat(sin(angle)),
                       y: center.y - radius * CGFloat(cos(angle)))
    }

    /// Minute value (0..<60) of a point relative to the dial center.
    static func minutes(at point: CGPoint, center: CGPoint) -> Double {
        var angle = atan2(Double(center.x - point.x), Double(center.y - point.y))
        if angle < 0 { angle += 2 * Double.pi }
        return angle / (2 * Double.pi) * 60
    }
}

/// The purely visual timer. All sizes are fractions of the window side `size`.
struct TimerFace: View {
    static let faceInset: CGFloat = 0.075
    static let diskRadius: CGFloat = 0.325
    static let knobRadius: CGFloat = 0.068
    static let tabX: CGFloat = 1 - faceInset / 2
    static let tabTravel: CGFloat = 0.3

    /// Opacity tab position (fraction of size): top = opaque, bottom = most transparent.
    static func tabY(forOpacity opacity: Double) -> CGFloat {
        let t = CGFloat((opacity - TimerLimits.minOpacity) / (1 - TimerLimits.minOpacity))
        return 0.5 + tabTravel / 2 - t * tabTravel
    }

    static func opacity(forTabY y: CGFloat, size s: CGFloat) -> Double {
        let t = min(max((s * (0.5 + tabTravel / 2) - y) / (s * tabTravel), 0), 1)
        return TimerLimits.minOpacity + Double(t) * (1 - TimerLimits.minOpacity)
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    let remaining: TimeInterval
    let isRunning: Bool
    let opacity: Double
    let knobHovered: Bool
    let theme: Theme
    let size: CGFloat

    private var minutes: Double { remaining / 60 }

    var body: some View {
        let s = size
        ZStack {
            bezel
            face
            DialMarks(size: s)
            RemainingWedge(minutes: minutes)
                .fill(LinearGradient(colors: [theme.diskTop, theme.diskBottom],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: s * Self.diskRadius * 2, height: s * Self.diskRadius * 2)
                .shadow(color: .black.opacity(0.28), radius: s * 0.012, x: 0, y: s * 0.006)
            glass
            Knob(minutes: minutes, isRunning: isRunning, hovered: knobHovered, theme: theme, size: s)
            readout
            opacityTab
        }
        .frame(width: s, height: s)
    }

    private var bezel: some View {
        let s = size
        let shape = RoundedRectangle(cornerRadius: s * 0.2, style: .continuous)
        return ZStack {
            shape.fill(LinearGradient(colors: [theme.bezelTop, theme.bezelBottom],
                                      startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05), .black.opacity(0.2)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: max(1, s * 0.008))
            // Soft inner lip where the bezel meets the face.
            RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: s * 0.012)
                .blur(radius: s * 0.006)
                .padding(s * 0.052)
        }
    }

    private var face: some View {
        let s = size
        let shape = RoundedRectangle(cornerRadius: s * 0.13, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Palette.face, Palette.faceShade],
                                 startPoint: .top, endPoint: .bottom))
            // Inner shadow: the face sits recessed inside the bezel.
            .overlay(
                shape.stroke(Color.black.opacity(0.35), lineWidth: s * 0.02)
                    .blur(radius: s * 0.012)
                    .offset(y: s * 0.004)
                    .mask(shape)
            )
            .overlay(shape.stroke(Color.black.opacity(0.12), lineWidth: 1))
            .padding(s * Self.faceInset)
    }

    /// Faint lens reflection over the face.
    private var glass: some View {
        let s = size
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.13, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0)],
                                     startPoint: .topLeading, endPoint: UnitPoint(x: 0.55, y: 0.5)))
                .padding(s * Self.faceInset)
            Circle()
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                .frame(width: s * 0.74, height: s * 0.74)
        }
    }

    private var readout: some View {
        let s = size
        return Text(Self.format(remaining))
            .font(.system(size: s * 0.05, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(theme.label.opacity(isRunning || remaining == 0 ? 1 : 0.7))
            .position(x: s * 0.78, y: s * 0.885)
    }

    /// The small slider on the right side of the bezel that sets transparency.
    private var opacityTab: some View {
        let s = size
        return ZStack {
            Capsule()
                .fill(Color.black.opacity(0.2))
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5).offset(y: 0.5))
                .frame(width: s * 0.012, height: s * Self.tabTravel)
                .position(x: s * Self.tabX, y: s * 0.5)
            RoundedRectangle(cornerRadius: s * 0.01, style: .continuous)
                .fill(LinearGradient(colors: [theme.knobLight, theme.knobDark],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(
                    VStack(spacing: s * 0.008) {
                        ForEach(0..<3) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.25))
                                .frame(width: s * 0.018, height: max(0.5, s * 0.003))
                        }
                    }
                )
                .frame(width: s * 0.034, height: s * 0.075)
                .shadow(color: .black.opacity(0.3), radius: s * 0.006, x: 0, y: s * 0.003)
                .position(x: s * Self.tabX, y: s * Self.tabY(forOpacity: opacity))
        }
    }
}

/// Tick marks and numerals 0, 5, ... 55 running counter-clockwise.
struct DialMarks: View {
    let size: CGFloat

    var body: some View {
        let s = size
        Canvas { ctx, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            for i in 0..<60 {
                let major = i % 5 == 0
                var tick = Path()
                tick.move(to: DialGeometry.point(minutes: Double(i), radius: s * 0.332, center: center))
                tick.addLine(to: DialGeometry.point(minutes: Double(i),
                                                    radius: s * (major ? 0.36 : 0.347), center: center))
                ctx.stroke(tick,
                           with: .color(Palette.ink.opacity(major ? 0.95 : 0.7)),
                           style: StrokeStyle(lineWidth: s * (major ? 0.009 : 0.004), lineCap: .butt))
            }
            for n in stride(from: 0, to: 60, by: 5) {
                let label = Text("\(n)")
                    .font(.system(size: s * 0.056, weight: .medium))
                    .foregroundColor(Palette.ink)
                ctx.draw(label, at: DialGeometry.point(minutes: Double(n), radius: s * 0.39, center: center))
            }
        }
        .frame(width: s, height: s)
    }
}

/// The colored disk showing remaining time, from 12 o'clock sweeping counter-clockwise.
struct RemainingWedge: Shape {
    var minutes: Double

    var animatableData: Double {
        get { minutes }
        set { minutes = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        guard minutes > 0.001 else { return path }
        if minutes >= 59.999 {
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2))
            return path
        }
        path.move(to: center)
        let steps = max(2, Int(minutes * 4))
        for i in 0...steps {
            let m = minutes * Double(i) / Double(steps)
            path.addLine(to: DialGeometry.point(minutes: m, radius: radius, center: center))
        }
        path.closeSubpath()
        return path
    }
}

/// Center knob with a pointer nub that follows the edge of the disk.
struct Knob: View {
    let minutes: Double
    let isRunning: Bool
    let hovered: Bool
    let theme: Theme
    let size: CGFloat

    var body: some View {
        let r = size * TimerFace.knobRadius
        let nubLength = r + size * 0.055
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.008, style: .continuous)
                .fill(LinearGradient(colors: [theme.knobLight, theme.knobDark],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: size * 0.024, height: nubLength)
                .frame(width: nubLength * 2, height: nubLength * 2, alignment: .top)
                .rotationEffect(.degrees(-minutes * 6))
            Circle()
                .fill(RadialGradient(colors: [theme.knobLight, theme.knobDark],
                                     center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 0, endRadius: r * 1.7))
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: max(0.5, size * 0.003)))
                .frame(width: r * 2, height: r * 2)
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: r * 0.7, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .opacity(hovered ? 1 : 0)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: size * 0.012, x: size * 0.004, y: size * 0.01)
    }
}

/// Highlight along the top-left bezel corner, shown while hovering a resize corner.
/// Rotate it to place it on the other corners.
struct CornerGrip: View {
    let size: CGFloat

    var body: some View {
        let s = size
        let cornerRadius = s * 0.2
        Path { path in
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                        radius: cornerRadius - s * 0.035,
                        startAngle: .degrees(200), endAngle: .degrees(250),
                        clockwise: false)
        }
        .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round))
        .shadow(color: .black.opacity(0.2), radius: s * 0.004, x: 0, y: s * 0.002)
        .frame(width: s, height: s)
    }
}
