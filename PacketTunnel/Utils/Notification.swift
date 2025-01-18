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
        content.title = "request_captured".localizedString
        content.body = "request_captured_body".localizedString
        content.userInfo = [
            RequestHeaders: requestHeaders,
            ResponseHeaders: responseHeaders as Any,
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
