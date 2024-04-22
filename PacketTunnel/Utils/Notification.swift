import Foundation
import UserNotifications
import OSLog

class NotificationService {
    static var notificationSent = false
}

func scheduleNotification(requestHeaders: String, requestBody: Data?, responseHeaders: String?, responseBody: Data?) {
    if !NotificationService.notificationSent {
        NotificationService.notificationSent = true
        let content = UNMutableNotificationContent()
        content.title = "Request Captured"
        content.body = "Please press the notification to continue in Mudmouth."
        content.userInfo = [
            "requestHeaders": requestHeaders,
            "requestBody": requestBody as Any,
            "responseHeaders": responseHeaders as Any,
            "responseBody": responseBody as Any,
        ]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                os_log(.error, "Failed to schedule notification: %{public}@", error!.localizedDescription)
            }
        }
    }
}
