import AVFoundation
import UIKit
import UserNotifications

/// End-of-timer alerts: a scheduled notification (works when the app is closed)
/// and an in-app chime + haptic when the app is open.
@MainActor
enum Alerts {
    private static let notificationID = "pomodoro.timer.done"
    private static let soundFile = "chime.wav"
    private static var player: AVAudioPlayer?

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func schedule(at date: Date, minutes: Double) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time's up!"
        let m = Int(minutes.rounded())
        content.body = m > 0 ? "Your \(m)-minute timer is done. Take a break." : "Your timer is done."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    /// The app is open when time runs out: chime + haptic (the banner shows without sound).
    static func ringInApp() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

/// Shows the banner while the app is in the foreground; the app plays the chime itself.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
