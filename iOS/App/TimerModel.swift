import SwiftUI
import UIKit
import WidgetKit

/// Timer state. A running timer is tracked by its end date (stored in the App Group),
/// so it stays correct while the app is suspended or killed; the notification fires on time.
@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning = false

    /// Saved after a short pause so dragging around the color picker doesn't
    /// restart the Live Activity on every change.
    @Published var theme: Theme {
        didSet {
            themeSaveTask?.cancel()
            themeSaveTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                self?.persist()
            }
        }
    }
    private var themeSaveTask: Task<Void, Never>?

    @Published var keepAwake: Bool {
        didSet {
            defaults.set(keepAwake, forKey: Keys.keepAwake)
            applyIdleTimer()
        }
    }

    @Published var liveActivityEnabled: Bool {
        didSet {
            defaults.set(liveActivityEnabled, forKey: Keys.liveActivity)
            syncLiveActivity()
        }
    }

    /// The last duration the user dialed in; tapping the knob at 0 restarts it.
    private(set) var lastSetSeconds: TimeInterval

    private var endDate: Date?
    private var ticker: Timer?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let keepAwake = "keepAwake"
        static let liveActivity = "liveActivity"
        static let lastSetSeconds = "lastSetSeconds"
    }

    init() {
        let defaults = UserDefaults.standard
        let snapshot = SharedStore.load()
        theme = snapshot.theme
        keepAwake = defaults.object(forKey: Keys.keepAwake) as? Bool ?? true
        liveActivityEnabled = defaults.object(forKey: Keys.liveActivity) as? Bool ?? true
        let last = defaults.double(forKey: Keys.lastSetSeconds)
        lastSetSeconds = last > 0 ? last : 25 * 60
        remaining = snapshot.remaining()
        if snapshot.isRunning(), let end = snapshot.endDate {
            endDate = end
            isRunning = true
            startTicker()
        }
    }

    // MARK: - Setting

    /// Sets the dial while dragging. If running, the countdown continues from the new value.
    func setRemaining(_ seconds: TimeInterval) {
        let value = min(max(seconds, 0), TimerLimits.maxSeconds)
        remaining = value
        guard isRunning else { return }
        if value == 0 {
            stopRunning()
            Alerts.cancel()
            persist()
        } else {
            endDate = Date().addingTimeInterval(value)
        }
    }

    /// Called when a dial drag ends: remember the duration and update notification, widget, Live Activity.
    func commitSetting() {
        if remaining > 0 {
            lastSetSeconds = remaining.rounded()
            defaults.set(lastSetSeconds, forKey: Keys.lastSetSeconds)
        }
        if isRunning, let endDate {
            Alerts.schedule(at: endDate, minutes: lastSetSeconds / 60)
        }
        persist()
    }

    func startPreset(minutes: Int) {
        setRemaining(TimeInterval(minutes) * 60)
        commitSetting()
        start()
    }

    // MARK: - Running

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        if remaining <= 0 {
            guard lastSetSeconds > 0 else { return }
            remaining = lastSetSeconds
        }
        let end = Date().addingTimeInterval(remaining)
        endDate = end
        isRunning = true
        startTicker()
        Alerts.requestAuthorization()
        Alerts.schedule(at: end, minutes: lastSetSeconds / 60)
        persist()
    }

    func pause() {
        tick()
        guard isRunning else { return }
        stopRunning()
        Alerts.cancel()
        persist()
    }

    func reset() {
        stopRunning()
        remaining = 0
        Alerts.cancel()
        persist()
    }

    /// Re-reads the clock when the app returns to the foreground.
    func resync() {
        guard let endDate else {
            // Clear a Lock Screen countdown left over from a timer that finished while closed.
            if remaining == 0 { LiveActivityManager.endAll() }
            return
        }
        if endDate <= Date() {
            // Finished while in the background; the notification already rang.
            stopRunning()
            remaining = 0
            persist()
        } else {
            remaining = endDate.timeIntervalSinceNow
            startTicker()
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        applyIdleTimer()
    }

    private func stopRunning() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
        applyIdleTimer()
    }

    private func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            finish()
        } else {
            remaining = left
        }
    }

    private func finish() {
        stopRunning()
        remaining = 0
        Alerts.ringInApp()
        persist()
    }

    // MARK: - Side effects

    private func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepAwake && isRunning
    }

    /// Saves shared state and refreshes the widget and Live Activity.
    private func persist() {
        let snapshot = TimerSnapshot(endDate: isRunning ? endDate : nil,
                                     pausedRemaining: remaining,
                                     theme: theme)
        SharedStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        syncLiveActivity()
    }

    private func syncLiveActivity() {
        guard liveActivityEnabled else {
            LiveActivityManager.endAll()
            return
        }
        if isRunning, let endDate {
            LiveActivityManager.show(state: .init(endDate: endDate, pausedRemaining: remaining), theme: theme)
        } else if remaining > 0 && remaining < lastSetSeconds {
            // Paused mid-session.
            LiveActivityManager.show(state: .init(endDate: nil, pausedRemaining: remaining), theme: theme)
        } else {
            LiveActivityManager.endAll()
        }
    }
}
