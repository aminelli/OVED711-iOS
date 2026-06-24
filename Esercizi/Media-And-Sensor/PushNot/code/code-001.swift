// Esempio NotificationService e AppDelegate (con setup)

import UserNotifications
import UIKit

// MARK: - Notification Service Actor

actor NotificationService: NSObject {
    // MARK: - Richiesta permessi

    func requestAuthorization(options: UNAuthorizationOptions = [.alert, .badge, .sound]) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: options)
    }

    // MARK: - Registrazione remota

    @MainActor
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Stato corrente

    func notificationSettings() async -> UNNotificationSettings {
        await UNUserNotificationCenter.current().notificationSettings()
    }

    // MARK: - Notifica locale (test)

    func scheduleLocal(title: String, body: String, after seconds: TimeInterval = 5) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Rimozione

    func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - AppDelegate

@main
struct PushApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let notificationService = NotificationService()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs device token: \(token)")
        // Inviare `token` al proprio backend
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Registrazione APNs fallita: \(error)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Notifica ricevuta con app in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Utente ha tappato la notifica
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationTap(response: response, userInfo: userInfo)
        completionHandler()
    }

    private func handleNotificationTap(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                print("Risposta utente: \(textResponse.userText)")
            }
        case UNNotificationDefaultActionIdentifier:
            print("Tap su notifica: \(userInfo)")
        default:
            break
        }
    }
}