import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let triviaEnabled = notification.request.content.userInfo["triviaEnabled"] as? Bool ?? true
        if triviaEnabled,
           let alarmID = UUID(uuidString: notification.request.content.userInfo["alarmID"] as? String ?? "") {
            // Alarm dismissal behavior: foreground fallback notifications immediately show
            // the in-app trivia gate. The alarm is not considered dismissed until this view
            // calls AlarmSchedulingService.dismiss(alarm:).
            await AlarmRuntimeStore.shared.present(alarmID: alarmID)
        }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let triviaEnabled = response.notification.request.content.userInfo["triviaEnabled"] as? Bool ?? true
        if triviaEnabled,
           let alarmID = UUID(uuidString: response.notification.request.content.userInfo["alarmID"] as? String ?? "") {
            // When the app is launched from the notification, route into the same full-screen
            // trivia dismissal view used by AlarmKit alert-state updates.
            await AlarmRuntimeStore.shared.present(alarmID: alarmID)
        }
    }
}
