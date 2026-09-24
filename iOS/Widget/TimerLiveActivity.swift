import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen banner and Dynamic Island while the timer runs or is paused.
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state, theme: context.attributes.theme)
                .activityBackgroundTint(Palette.face)
                .activitySystemActionForegroundColor(context.attributes.theme.disk.color)
        } dynamicIsland: { context in
            let state = context.state
            let theme = context.attributes.theme
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DialRing(state: state, theme: theme)
                        .frame(width: 44, height: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimeLeftText(state: state)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.disk.lighter(0.35).color)
                        .frame(maxWidth: 120, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(state.endDate == nil ? "Paused" : "Focus time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                DialRing(state: state, theme: theme)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                TimeLeftText(state: state)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.disk.lighter(0.35).color)
                    .frame(width: 44)
            } minimal: {
                DialRing(state: state, theme: theme)
                    .frame(width: 20, height: 20)
            }
            .keylineTint(theme.disk.color)
        }
    }
}

struct LockScreenActivityView: View {
    let state: TimerActivityAttributes.ContentState
    let theme: Theme

    var body: some View {
        HStack(spacing: 16) {
            DialRing(state: state, theme: theme)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.endDate == nil ? "Paused" : "Pomodoro")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.label)
                TimeLeftText(state: state)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

/// Counts down on its own while running; fixed while paused.
struct TimeLeftText: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if let end = state.endDate {
            Text(timerInterval: min(Date(), end)...end, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text(DialGeometry.format(state.pausedRemaining))
                .monospacedDigit()
        }
    }
}

/// Ring showing time left out of 60 minutes, like the disk on the dial.
/// While running the system animates it; while paused it's a static pie.
struct DialRing: View {
    let state: TimerActivityAttributes.ContentState
    let theme: Theme

    var body: some View {
        if let end = state.endDate {
            ProgressView(timerInterval: end.addingTimeInterval(-TimerLimits.maxSeconds)...end,
                         countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(theme.disk.color)
        } else {
            ZStack {
                Circle().fill(Palette.face)
                RemainingWedge(minutes: state.pausedRemaining / 60)
                    .fill(theme.disk.color)
                    .padding(2)
            }
        }
    }
}
