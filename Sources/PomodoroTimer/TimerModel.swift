import AppKit
import Combine

enum TimerLimits {
    static let maxSeconds: TimeInterval = 60 * 60
    static let minOpacity = 0.2
}

/// Timer state. Time is tracked against an end date so it stays accurate
/// through sleep, heavy load, and menu tracking.
@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning = false

    /// Window opacity, 0.2...1.0.
    @Published var opacity: Double {
        didSet {
            let clamped = min(max(opacity, TimerLimits.minOpacity), 1.0)
            if clamped != opacity { opacity = clamped }
            defaults.set(opacity, forKey: Keys.opacity)
        }
    }

    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    /// The last duration the user dialed in; clicking the knob at 0 restarts it.
    private(set) var lastSetSeconds: TimeInterval

    private var endDate: Date?
    private var ticker: Timer?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let opacity = "opacity"
        static let alwaysOnTop = "alwaysOnTop"
        static let lastSetSeconds = "lastSetSeconds"
    }

    init() {
        let defaults = UserDefaults.standard
        opacity = defaults.object(forKey: Keys.opacity) as? Double ?? 1.0
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        let last = defaults.double(forKey: Keys.lastSetSeconds)
        let initial = last > 0 ? last : 25 * 60
        lastSetSeconds = initial
        remaining = initial
    }

    // MARK: - Setting

    /// Sets the dial. If running, the countdown continues from the new value.
    func setRemaining(_ seconds: TimeInterval) {
        let value = min(max(seconds, 0), TimerLimits.maxSeconds)
        remaining = value
        guard isRunning else { return }
        if value == 0 {
            stop()
        } else {
            endDate = Date().addingTimeInterval(value)
        }
    }

    /// Remembers the current dial position as the default duration.
    func commitSetting() {
        guard remaining > 0 else { return }
        lastSetSeconds = remaining.rounded()
        defaults.set(lastSetSeconds, forKey: Keys.lastSetSeconds)
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
        stopTicker()
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func pause() {
        tick()
        stop()
    }

    func reset() {
        stop()
        remaining = 0
    }

    private func stop() {
        stopTicker()
        endDate = nil
        isRunning = false
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
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
        stop()
        remaining = 0
        Alarm.fire(durationSeconds: lastSetSeconds)
    }
}
