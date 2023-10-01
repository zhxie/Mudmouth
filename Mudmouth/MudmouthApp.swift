//
//  MudmouthApp.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

import SwiftUI
import OSLog

@main
struct MudmouthApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let headers = response.notification.request.content.userInfo["headers"] as? String
        if headers != nil {
            NotificationCenter.default.post(name: Notification.Name("notification"), object: nil, userInfo: ["headers": headers!])
        }
        completionHandler()
    }
}
