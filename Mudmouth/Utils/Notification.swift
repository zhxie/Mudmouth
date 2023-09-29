//
//  Notification.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/29.
//

import Foundation
import UserNotifications

func requestNotification(_ completion: @escaping (_ granted: Bool) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
        if let error = error {
            fatalError("Failed to request notification permission: \(error.localizedDescription)")
        }
        completion(granted)
    }
}
