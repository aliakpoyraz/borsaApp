import Foundation
import UIKit
import UserNotifications
import GoogleSignIn

public final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Firebase
        let clientID = "327055343915-j8o3i59pl3s5tsfclvtfeculq6648vad.apps.googleusercontent.com"
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Bildirim ayarları
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        
        return true
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([[.banner, .sound, .list]])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs Token Received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    }
    
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs Failed to register: \(error.localizedDescription)")
    }
}
