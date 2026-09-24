import AppKit
import SwiftUI

/// Moves the borderless window by tracking the mouse in screen coordinates,
/// so the drag stays stable while the window moves under the cursor.
@MainActor
final class WindowDragger {
    weak var window: NSWindow?
    private var startOrigin: NSPoint?
    private var startMouse: NSPoint = .zero

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
}

/// The timer plus its mouse interactions, layered as invisible hit areas over the face:
/// - drag the dial to set minutes
/// - click the knob to start/pause, double-click to reset
/// - drag the side tab to change transparency
/// - drag anywhere else to move the window
@MainActor
struct TimerView: View {
    private static let space = "timer"

    @ObservedObject var model: TimerModel
    let dragger: WindowDragger

    @State private var lastDialMinute: Double?
    @State private var knobHovered = false

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                TimerFace(remaining: model.remaining,
                          isRunning: model.isRunning,
                          opacity: model.opacity,
                          knobHovered: knobHovered,
                          size: s)
                    .allowsHitTesting(false)
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
