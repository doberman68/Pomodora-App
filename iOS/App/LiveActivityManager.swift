import ActivityKit
import Foundation

/// Starts, updates and ends the Lock Screen / Dynamic Island countdown.
@MainActor
enum LiveActivityManager {
    private static var current: Activity<TimerActivityAttributes>? {
        Activity<TimerActivityAttributes>.activities.first
    }

    static func show(state: TimerActivityAttributes.ContentState, theme: Theme) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Past the end date the system marks it stale; the app ends it on next launch.
        let content = ActivityContent(state: state, staleDate: state.endDate)

        if let activity = current, activity.attributes.theme == theme {
            Task { await activity.update(content) }
            return
        }
        // Theme is fixed per activity, so a color change starts a new one.
        endAll()
        _ = try? Activity.request(attributes: TimerActivityAttributes(theme: theme),
                                  content: content,
                                  pushType: nil)
    }

    static func endAll() {
        for activity in Activity<TimerActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
