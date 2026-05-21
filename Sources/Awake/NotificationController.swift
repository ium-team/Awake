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

    func notifySessionEnded(targetCount: Int, language: AppLanguage) {
        let l10n = L10n(language: language)
        notify(
            title: l10n.text(.awakeStopped),
            body: targetCount == 1
                ? l10n.text(.selectedAppFinished)
                : l10n.text(.allSelectedAppsFinished)
        )
    }

    func notifySafetyStop(reason: String, language: AppLanguage) {
        notify(title: L10n(language: language).text(.awakeRestoredMacOSSleep), body: reason)
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: "awake.notification.\(UUID().uuidString)",
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
