import SwiftUI
import UserNotifications

@main
struct PomodoroApp: App {
    @StateObject private var model = TimerModel()
    @Environment(\.scenePhase) private var scenePhase
    /// Held statically: the notification center keeps only a weak reference.
    private static let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.resync() }
        }
    }
}
