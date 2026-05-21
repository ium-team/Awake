import Foundation
import UserNotifications

final class NotificationController: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifySessionEnded(targetCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Awake stopped"
        content.body = targetCount == 1
            ? "The selected app finished, so Awake released the power assertion."
            : "All selected apps finished, so Awake released the power assertion."

        let request = UNNotificationRequest(
            identifier: "awake.session-ended.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
