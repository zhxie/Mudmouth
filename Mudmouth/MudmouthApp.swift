import CoreData
import OSLog
import SwiftUI

@main
struct MudmouthApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    UserDefaults.standard.register(defaults: ["version": 0])
                    let version = UserDefaults.standard.integer(forKey: "version")
                    if version < 1 {
                        let context = PersistenceController.shared.container.viewContext
                        let fetchRequest: NSFetchRequest<Profile> = Profile.fetchRequest()
                        fetchRequest.predicate = NSPredicate(value: true)
                        do {
                            let count = try context.count(for: fetchRequest)
                            if count == 0 {
                                let profile = Profile(context: context)
                                profile.name = "httpbin.org"
                                profile.url = "http://httpbin.org/get"
                                profile.directionEnum = .requestAndResponse
                                try context.save()
                            }
                            UserDefaults.standard.set(1, forKey: "version")
                        } catch {
                            os_log(
                                .error, "Failed to initialize default profile: %{public}@", error.localizedDescription)
                        }
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let requestHeaders = response.notification.request.content.userInfo["requestHeaders"] as? String
        let requestBody = response.notification.request.content.userInfo["requestBody"] as? Data
        let responseHeaders = response.notification.request.content.userInfo["responseHeaders"] as? String
        let responseBody = response.notification.request.content.userInfo["responseBody"] as? Data
        if requestHeaders != nil {
            NotificationCenter.default.post(
                name: Notification.Name("notification"), object: nil,
                userInfo: [
                    "requestHeaders": requestHeaders!, "requestBody": requestBody as Any,
                    "responseHeaders": responseHeaders as Any, "responseBody": responseBody as Any,
                ])
        }
        completionHandler()
    }
}
