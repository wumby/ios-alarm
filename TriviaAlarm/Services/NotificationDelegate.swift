import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if let alarmID = UUID(uuidString: notification.request.content.userInfo["alarmID"] as? String ?? "") {
            // Foreground fallback notifications immediately show the in-app trivia gate or
            // no-trivia completion screen. The alarm is not considered dismissed until this
            // view calls AlarmSchedulingService.dismiss(alarm:).
            await AlarmRuntimeStore.shared.present(alarmID: alarmID)
        }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let alarmID = UUID(uuidString: response.notification.request.content.userInfo["alarmID"] as? String ?? "") {
            // When the app is launched from the notification, route into the same full-screen
            // trivia dismissal or no-trivia completion view used by AlarmKit alert-state updates.
            await AlarmRuntimeStore.shared.present(alarmID: alarmID)
        }
    }
}
