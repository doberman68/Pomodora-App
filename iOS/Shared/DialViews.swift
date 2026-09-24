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

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// The visual timer. All sizes are fractions of the side length `size`.
struct TimerFace: View {
    static let faceInset: CGFloat = 0.075
    static let diskRadius: CGFloat = 0.325
    static let knobRadius: CGFloat = 0.068

    enum Readout {
        case hidden
        case fixed
        /// Counts down on its own (widgets and Live Activities can't redraw every second).
        case live(end: Date)
    }

    let remaining: TimeInterval
    let isRunning: Bool
    let theme: Theme
    let size: CGFloat
    var showsBezel = true
    var showsGlyph = true
    var readout: Readout = .fixed

    private var minutes: Double { remaining / 60 }

    var body: some View {
        let s = size
        ZStack {
            if showsBezel { bezel }
            face
            DialMarks(size: s)
            RemainingWedge(minutes: minutes)
                .fill(LinearGradient(colors: [theme.diskTop, theme.diskBottom],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: s * Self.diskRadius * 2, height: s * Self.diskRadius * 2)
                .shadow(color: .black.opacity(0.28), radius: s * 0.012, x: 0, y: s * 0.006)
            glass
            Knob(minutes: minutes, isRunning: isRunning, showsGlyph: showsGlyph, theme: theme, size: s)
            readoutView
        }
        .frame(width: s, height: s)
    }

    private var bezel: some View {
        let s = size
        let shape = RoundedRectangle(cornerRadius: s * 0.2, style: .continuous)
        return ZStack {
            shape.fill(theme.bezelGradient)
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05), .black.opacity(0.2)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: max(1, s * 0.008))
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
            .overlay(
                shape.stroke(Color.black.opacity(0.35), lineWidth: s * 0.02)
                    .blur(radius: s * 0.012)
                    .offset(y: s * 0.004)
                    .mask(shape)
            )
            .overlay(shape.stroke(Color.black.opacity(0.12), lineWidth: 1))
            .padding(s * Self.faceInset)
    }

    private var glass: some View {
        let s = size
        return RoundedRectangle(cornerRadius: s * 0.13, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0)],
                                 startPoint: .topLeading, endPoint: UnitPoint(x: 0.55, y: 0.5)))
            .padding(s * Self.faceInset)
    }

    @ViewBuilder
    private var readoutView: some View {
        let s = size
        let font = Font.system(size: s * 0.05, weight: .bold, design: .rounded)
        let color = theme.label.opacity(isRunning || remaining == 0 ? 1 : 0.7)
        switch readout {
        case .hidden:
            EmptyView()
        case .fixed:
            Text(DialGeometry.format(remaining))
                .font(font).monospacedDigit().foregroundColor(color)
                .position(x: s * 0.78, y: s * 0.885)
        case .live(let end):
            Text(timerInterval: min(Date(), end)...end, countsDown: true)
                .font(font).monospacedDigit().foregroundColor(color)
                .multilineTextAlignment(.center)
                .frame(width: s * 0.2)
                .position(x: s * 0.78, y: s * 0.885)
        }
    }
}

/// Tick marks and numerals 0, 5, ... 55 running counter-clockwise.
/// Built from shapes and text (no Canvas) so it also renders in widgets.
struct DialMarks: View {
    let size: CGFloat

    var body: some View {
        let s = size
        let center = CGPoint(x: s / 2, y: s / 2)
        ZStack {
            ticks(major: false, center: center)
                .stroke(Palette.ink.opacity(0.7), lineWidth: s * 0.004)
            ticks(major: true, center: center)
                .stroke(Palette.ink.opacity(0.95), lineWidth: s * 0.009)
            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { n in
                Text("\(n)")
                    .font(.system(size: s * 0.056, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .fixedSize()
                    .position(DialGeometry.point(minutes: Double(n), radius: s * 0.39, center: center))
            }
        }
        .frame(width: s, height: s)
    }

    private func ticks(major: Bool, center: CGPoint) -> Path {
        let s = size
        var path = Path()
        for i in 0..<60 where (i % 5 == 0) == major {
            path.move(to: DialGeometry.point(minutes: Double(i), radius: s * 0.332, center: center))
            path.addLine(to: DialGeometry.point(minutes: Double(i),
                                                radius: s * (major ? 0.36 : 0.347), center: center))
        }
        return path
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
    let showsGlyph: Bool
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
            if showsGlyph {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: r * 0.7, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: size * 0.012, x: size * 0.004, y: size * 0.01)
    }
}
