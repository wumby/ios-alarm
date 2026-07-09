import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Local notification setup: when AlarmKit is unavailable, this delegate lets the
        // app open directly into the trivia dismissal flow after the user taps an alarm.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        return true
    }
}

