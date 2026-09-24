import ActivityKit
import Foundation

enum TimerLimits {
    static let maxSeconds: TimeInterval = 60 * 60
}

/// Timer state shared between the app and the widget through the App Group.
/// A running timer is stored as its end date, so any process can compute what's left.
struct TimerSnapshot: Codable, Equatable {
    /// Set while running.
    var endDate: Date?
    /// Time left while paused or idle.
    var pausedRemaining: TimeInterval
    var theme: Theme

    static let initial = TimerSnapshot(endDate: nil, pausedRemaining: 25 * 60, theme: .slate)

    func remaining(at date: Date = Date()) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        return pausedRemaining
    }

    func isRunning(at date: Date = Date()) -> Bool {
        guard let endDate else { return false }
        return endDate > date
    }
}

enum SharedStore {
    /// Must match the App Group in project.yml.
    static let appGroup = "group.com.doberman68.pomodorotimer"
    private static let key = "timerSnapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> TimerSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(TimerSnapshot.self, from: data)
        else { return .initial }
        return snapshot
    }

    static func save(_ snapshot: TimerSnapshot) {
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: key)
    }
}

/// Live Activity (Lock Screen + Dynamic Island) data.
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Set while running.
        var endDate: Date?
        /// Time left while paused.
        var pausedRemaining: TimeInterval
    }

    var theme: Theme
}
