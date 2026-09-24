import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: TimerModel
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let side = min(landscape
                           ? min(geo.size.height - 32, geo.size.width - 220)
                           : min(geo.size.width - 40, geo.size.height - 230),
                           720)
            ZStack {
                LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                if landscape {
                    HStack(spacing: 36) {
                        DialView(side: side)
                        ControlsView(showSettings: $showSettings)
                    }
                } else {
                    VStack(spacing: 32) {
                        DialView(side: side)
                        ControlsView(showSettings: $showSettings)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(model)
        }
    }
}

/// The timer with touch controls:
/// - drag the dial to set minutes (haptic tick per minute)
/// - tap the knob to start/pause, double-tap to reset
struct DialView: View {
    @EnvironmentObject private var model: TimerModel
    let side: CGFloat

    @State private var lastDialMinute: Double?
    private let haptics = UISelectionFeedbackGenerator()

    var body: some View {
        let knobDiameter = side * TimerFace.knobRadius * 2.6
        ZStack {
            TimerFace(remaining: model.remaining, isRunning: model.isRunning,
                      theme: model.theme, size: side)
                .allowsHitTesting(false)

            Color.clear
                .frame(width: side * 0.85, height: side * 0.85)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named("dial"))
                        .onChanged { value in dialChanged(to: value.location) }
                        .onEnded { _ in
                            lastDialMinute = nil
                            model.commitSetting()
                        }
                )

            Color.clear
                .frame(width: knobDiameter, height: knobDiameter)
                .contentShape(Circle())
                .gesture(
                    TapGesture(count: 2)
                        .onEnded { withAnimation(.easeInOut(duration: 0.5)) { model.reset() } }
                        .exclusively(before: TapGesture().onEnded { model.toggle() })
                )
        }
        .frame(width: side, height: side)
        .coordinateSpace(.named("dial"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer")
        .accessibilityValue("\(DialGeometry.format(model.remaining)) remaining")
        .accessibilityAdjustableAction { direction in
            let minutes = (model.remaining / 60).rounded()
            model.setRemaining((direction == .increment ? minutes + 1 : minutes - 1) * 60)
            model.commitSetting()
        }
        .accessibilityAction(named: model.isRunning ? "Pause" : "Start") { model.toggle() }
    }

    private func dialChanged(to location: CGPoint) {
        let center = CGPoint(x: side / 2, y: side / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        // Angles are jittery right at the center; ignore the knob area.
        guard (dx * dx + dy * dy).squareRoot() > side * 0.06 else { return }

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
        haptics.selectionChanged()
        model.setRemaining(minute * 60)
    }
}

struct ControlsView: View {
    @EnvironmentObject private var model: TimerModel
    @Binding var showSettings: Bool

    private static let presets = [25, 5, 15, 50]

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 28) {
                iconButton("arrow.counterclockwise", label: "Reset") {
                    withAnimation(.easeInOut(duration: 0.5)) { model.reset() }
                }
                Button {
                    model.toggle()
                } label: {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(model.theme.disk.color))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .accessibilityLabel(model.isRunning ? "Pause" : "Start")
                iconButton("gearshape", label: "Settings") { showSettings = true }
            }
            HStack(spacing: 10) {
                ForEach(Self.presets, id: \.self) { minutes in
                    Button("\(minutes) min") { model.startPreset(minutes: minutes) }
                        .buttonStyle(.bordered)
                        .tint(model.theme.disk.color)
                }
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color(.tertiarySystemFill)))
        }
        .foregroundStyle(.primary)
        .accessibilityLabel(label)
    }
}
