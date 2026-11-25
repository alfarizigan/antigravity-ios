import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let antigravityOpenURL = Notification.Name("AntigravityOpenURLNotification")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        clearAppBadge(application)
        endGraceBackgroundTask()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        CookieManager.shared.flushImmediately()
        beginGraceBackgroundTask(application)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        CookieManager.shared.flushImmediately()
    }

    private func clearAppBadge(_ application: UIApplication) {
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
            application.applicationIconBadgeNumber = 0
        }
    }

    private func beginGraceBackgroundTask(_ application: UIApplication) {
        endGraceBackgroundTask()
        backgroundTaskID = application.beginBackgroundTask(withName: "AntigravityStreamSync") { [weak self] in
            self?.endGraceBackgroundTask()
        }
    }

    private func endGraceBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // Present native iOS notification banners + sound even while app is open in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge, .sound])
    }

    // Route notification banner taps cleanly into the active session
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        clearAppBadge(UIApplication.shared)
        if let urlStr = response.notification.request.content.userInfo["url"] as? String,
           let targetURL = URL(string: urlStr) {
            NotificationCenter.default.post(name: .antigravityOpenURL, object: targetURL)
        }
        completionHandler()
    }
}

@main
struct AntigravityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { incomingURL in
                    handleIncomingURL(incomingURL)
                }
        }
    }

    private func handleIncomingURL(_ incomingURL: URL) {
        let scheme = incomingURL.scheme?.lowercased() ?? ""
        if scheme == "antigravity" {
            // Convert antigravity://r/<id>?p=... -> https://antigravity.google.com/r/<id>?p=...
            var pathPart = incomingURL.host ?? ""
            if !incomingURL.path.isEmpty {
                pathPart += incomingURL.path
            }
            if let query = incomingURL.query, !query.isEmpty {
                pathPart += "?\(query)"
            }
            let targetString = pathPart.isEmpty
                ? CookieManager.defaultAppURLString
                : "\(CookieManager.defaultAppURLString)/\(pathPart)"
            if let targetURL = URL(string: targetString) {
                NotificationCenter.default.post(name: .antigravityOpenURL, object: targetURL)
            }
        } else if scheme == "https" || scheme == "http" {
            NotificationCenter.default.post(name: .antigravityOpenURL, object: incomingURL)
        }
    }
}
