//
//  Notification.swift
//  PacketTunnel
//
//  Created by Xie Zhihao on 2023/9/30.
//

import Foundation
import UserNotifications
import OSLog

class NotificationService {
    static var notificationSent = false
}

func scheduleNotification(_ headers: String) {
    if !NotificationService.notificationSent {
        NotificationService.notificationSent = true
        let content = UNMutableNotificationContent()
        content.title = "Request Hit"
        content.body = "Please press the notification to continue in Mudmouth."
        content.userInfo = [
            "headers": headers
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
