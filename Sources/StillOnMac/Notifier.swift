import Foundation
import UserNotifications

/// Posts the "Restart blocked" banner, with an "Allow Restart Once" action.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private static let categoryID = "RESTART_BLOCKED"
    private static let allowOnceID = "ALLOW_ONCE"

    var onAllowOnce: (() -> Void)?

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let allowOnce = UNNotificationAction(identifier: Self.allowOnceID, title: "Allow Restart Once", options: [])
        let category = UNNotificationCategory(
            identifier: Self.categoryID, actions: [allowOnce], intentIdentifiers: [], options: []
        )
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postRestartBlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Restart blocked"
        content.body = "A restart or shutdown was cancelled. Your Mac is still on and Claude Code keeps running."
        content.categoryIdentifier = Self.categoryID
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == Self.allowOnceID {
            DispatchQueue.main.async { self.onAllowOnce?() }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
