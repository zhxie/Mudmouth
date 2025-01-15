import Foundation
import OSLog
import UserNotifications

class NotificationService {
    static var notificationSent = false
}

func scheduleNotification(requestHeaders: String, responseHeaders: String?) {
    if !NotificationService.notificationSent {
        NotificationService.notificationSent = true
        let content = UNMutableNotificationContent()
        content.title = "Request Captured"
        content.body = "Tap to continue in Mudmouth."
        content.userInfo = [
            "requestHeaders": requestHeaders,
            "responseHeaders": responseHeaders as Any,
        ]
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                os_log(.error, "Failed to schedule notification: %{public}@", error!.localizedDescription)
            }
        }
    }
}
