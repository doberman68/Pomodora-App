import AppKit
import UserNotifications

/// Chime + notification when the timer reaches zero.
@MainActor
enum Alarm {
    private static var playing: [NSSound] = []

    /// UNUserNotificationCenter crashes when there is no app bundle (e.g. `swift run`).
    static var notificationsAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func fire(durationSeconds: TimeInterval) {
        playChime()
        postNotification(minutes: Int((durationSeconds / 60).rounded()))
    }

    private static func playChime() {
        Task { @MainActor in
            for i in 0..<3 {
                if i > 0 { try? await Task.sleep(nanoseconds: 700_000_000) }
                // Copies so overlapping rings don't cut each other off; retained until done.
                guard let sound = NSSound(named: "Glass")?.copy() as? NSSound else { return }
                playing.append(sound)
                sound.play()
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            playing.removeAll()
        }
    }

    private static func postNotification(minutes: Int) {
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time's up!"
        content.body = minutes > 0
            ? "Your \(minutes)-minute timer is done. Take a break."
            : "Your timer is done."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
