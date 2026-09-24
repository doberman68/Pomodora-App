import AppKit
import SwiftUI

enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var isLeft: Bool { self == .topLeft || self == .bottomLeft }
    var isTop: Bool { self == .topLeft || self == .topRight }

    /// Rotation that maps the top-left corner onto this one.
    var rotation: Angle {
        switch self {
        case .topLeft: return .degrees(0)
        case .topRight: return .degrees(90)
        case .bottomRight: return .degrees(180)
        case .bottomLeft: return .degrees(270)
        }
    }

    /// Diagonal resize cursor. AppKit has no public one before macOS 15,
    /// so use the system's private cursors when present.
    @MainActor
    var cursor: NSCursor {
        let name = (self == .topLeft || self == .bottomRight)
            ? "_windowResizeNorthWestSouthEastCursor"
            : "_windowResizeNorthEastSouthWestCursor"
        let selector = NSSelectorFromString(name)
        let cursorClass: AnyObject = NSCursor.self
        if cursorClass.responds(to: selector),
           let cursor = cursorClass.perform(selector)?.takeUnretainedValue() as? NSCursor {
            return cursor
        }
        return .crosshair
    }
}

/// Moves and resizes the borderless window by tracking the mouse in screen
/// coordinates, so drags stay stable while the window changes under the cursor.
@MainActor
final class WindowDragger {
    static let minSide: CGFloat = 160

    weak var window: NSWindow?
    private var startOrigin: NSPoint?
    private var startMouse: NSPoint = .zero
    private var resizeStart: (frame: NSRect, mouse: NSPoint)?

    func dragChanged() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if startOrigin == nil {
            startOrigin = window.frame.origin
            startMouse = mouse
        }
        guard let origin = startOrigin else { return }
        window.setFrameOrigin(NSPoint(x: origin.x + mouse.x - startMouse.x,
                                      y: origin.y + mouse.y - startMouse.y))
    }

    func dragEnded() {
        startOrigin = nil
    }

    /// Resizes from `corner`, keeping the window square and the opposite corner fixed.
    func resizeChanged(corner: Corner) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if resizeStart == nil {
            resizeStart = (window.frame, mouse)
        }
        guard let start = resizeStart else { return }

        // Screen coordinates: y grows upward.
        let dx = (mouse.x - start.mouse.x) * (corner.isLeft ? -1 : 1)
        let dy = (mouse.y - start.mouse.y) * (corner.isTop ? 1 : -1)
        let screen = window.screen?.visibleFrame.size ?? CGSize(width: 2000, height: 2000)
        let maxSide = max(Self.minSide, min(screen.width, screen.height))
        let side = min(max(start.frame.width + (dx + dy) / 2, Self.minSide), maxSide).rounded()

        let x = corner.isLeft ? start.frame.maxX - side : start.frame.minX
        let y = corner.isTop ? start.frame.minY : start.frame.maxY - side
        window.setFrame(NSRect(x: x, y: y, width: side, height: side), display: true)
    }

    func resizeEnded() {
        resizeStart = nil
        window?.invalidateShadow()
    }
}

/// The timer plus its mouse interactions, layered as invisible hit areas over the face:
/// - drag the dial to set minutes
/// - click the knob to start/pause, double-click to reset
/// - drag the side tab to change transparency
/// - drag a corner to resize
/// - drag anywhere else to move the window
@MainActor
struct TimerView: View {
    private static let space = "timer"

    @ObservedObject var model: TimerModel
    let dragger: WindowDragger

    @State private var lastDialMinute: Double?
    @State private var knobHovered = false
    @State private var hoveredCorner: Corner?

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                TimerFace(remaining: model.remaining,
                          isRunning: model.isRunning,
                          opacity: model.opacity,
                          knobHovered: knobHovered,
                          theme: model.theme,
                          size: s)
                    .allowsHitTesting(false)
                if let corner = hoveredCorner {
                    CornerGrip(size: s)
                        .rotationEffect(corner.rotation)
                        .allowsHitTesting(false)
                }
                interactionLayer(size: s)
            }
            .frame(width: s, height: s)
            .coordinateSpace(name: Self.space)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func interactionLayer(size s: CGFloat) -> some View {
        let knobDiameter = s * TimerFace.knobRadius * 2.4
        return ZStack {
            // Bezel and face corners: move the window.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in dragger.dragChanged() }
                        .onEnded { _ in dragger.dragEnded() }
                )

            // Dial: set the time.
            Color.clear
                .frame(width: s * 0.85, height: s * 0.85)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: CoordinateSpace.named(Self.space))
                        .onChanged { value in dialChanged(to: value.location, size: s) }
                        .onEnded { _ in dialEnded() }
                )

            // Knob: start / pause / reset.
            Color.clear
                .frame(width: knobDiameter, height: knobDiameter)
                .contentShape(Circle())
                .onHover { hovering in
                    knobHovered = hovering
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .gesture(
                    TapGesture(count: 2)
                        .onEnded { withAnimation(.easeInOut(duration: 0.5)) { model.reset() } }
                        .exclusively(before: TapGesture().onEnded { model.toggle() })
                )

            // Side tab: transparency.
            Color.clear
                .frame(width: s * TimerFace.faceInset, height: s * (TimerFace.tabTravel + 0.1))
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: CoordinateSpace.named(Self.space))
                        .onChanged { value in
                            model.opacity = TimerFace.opacity(forTabY: value.location.y, size: s)
                        }
                )
                .position(x: s * TimerFace.tabX, y: s * 0.5)

            // Corners: resize.
            ForEach(Corner.allCases, id: \.self) { corner in
                Color.clear
                    .frame(width: s * 0.13, height: s * 0.13)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        hoveredCorner = hovering ? corner : nil
                        if hovering { corner.cursor.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in dragger.resizeChanged(corner: corner) }
                            .onEnded { _ in dragger.resizeEnded() }
                    )
                    .position(x: s * (corner.isLeft ? 0.085 : 0.915),
                              y: s * (corner.isTop ? 0.085 : 0.915))
            }
        }
    }

    private func dialChanged(to location: CGPoint, size s: CGFloat) {
        let center = CGPoint(x: s / 2, y: s / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        // Angles are jittery right at the center; ignore the knob area.
        guard (dx * dx + dy * dy).squareRoot() > s * 0.06 else { return }

        var minute = DialGeometry.minutes(at: location, center: center).rounded()
        // Like the physical dial, the disk stops at 0 and 60 instead of wrapping around.
        if let last = lastDialMinute {
            if last >= 45 && minute <= 15 {
                minute = 60
            } else if last <= 15 && minute >= 45 {
                minute = 0
            }
        }
        guard minute != lastDialMinute else { return }
        lastDialMinute = minute
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        model.setRemaining(minute * 60)
    }

    private func dialEnded() {
        lastDialMinute = nil
        model.commitSetting()
    }
}
