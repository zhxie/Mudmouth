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
        let requestHeaders = response.notification.request.content.userInfo["requestHeaders"] as? String
        let requestBody = response.notification.request.content.userInfo["requestBody"] as? Data
        let responseHeaders = response.notification.request.content.userInfo["responseHeaders"] as? String
        let responseBody = response.notification.request.content.userInfo["responseBody"] as? Data
        if requestHeaders != nil {
            NotificationCenter.default.post(name: Notification.Name("notification"), object: nil, userInfo: ["requestHeaders": requestHeaders!, "requestBody": requestBody as Any, "responseHeaders": responseHeaders as Any, "responseBody": responseBody as Any])
        }
        completionHandler()
    }
}
