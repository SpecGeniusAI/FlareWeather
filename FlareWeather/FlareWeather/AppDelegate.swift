import UIKit
import UserNotifications
import Security

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    private let tokenKey = "flareweather_access_token"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // MARK: - Push Notification Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert token to string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        print("📱 APNs Device Token received: \(token.prefix(20))...")
        
        // Store token locally
        UserDefaults.standard.set(token, forKey: "apnsDeviceToken")
        
        // Send to backend if user is authenticated
        // Try multiple times with delays to ensure it's sent successfully
        Task {
            await sendTokenToBackend(token: token)
            // Retry after a delay in case auth wasn't ready yet (e.g., during signup)
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await sendTokenToBackend(token: token)
            // One more retry after login completes
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 more seconds
            await sendTokenToBackend(token: token)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Send Token to Backend
    
    func sendTokenToBackend(token: String) async {
        // Get auth token from keychain
        guard let authToken = loadAuthToken() else {
            print("⏭️ No auth token - will send push token after login")
            return
        }
        
        // Get backend URL
        guard let backendURL = Bundle.main.object(forInfoDictionaryKey: "BackendURL") as? String,
              let url = URL(string: "\(backendURL)/user/push-token") else {
            print("❌ Invalid backend URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["push_token": token]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Push token sent to backend successfully")
                } else {
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    print("⚠️ Failed to send push token: HTTP \(httpResponse.statusCode) - \(responseBody)")
                }
            }
        } catch {
            print("❌ Error sending push token: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handle Notifications
    
    // Called when notification received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📬 Notification tapped: \(userInfo)")
        
        // Handle notification tap - could navigate to specific screen
        if let type = userInfo["type"] as? String, type == "daily_forecast" {
            // Post notification to navigate to home/forecast view
            NotificationCenter.default.post(name: NSNotification.Name("OpenDailyForecast"), object: nil)
        }
        
        completionHandler()
    }
    
    // MARK: - Keychain Helper
    
    private func loadAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
}

// MARK: - Helper to send token after login or on app launch
extension AppDelegate {
    static func sendPushTokenIfNeeded() {
        guard let token = UserDefaults.standard.string(forKey: "apnsDeviceToken"), !token.isEmpty else {
            print("⏭️ No push token stored locally")
            return
        }
        
        print("📱 Attempting to send stored push token to backend...")
        Task {
            await AppDelegate().sendTokenToBackend(token: token)
        }
    }
    
    // Check and send token on app launch if user is logged in
    static func checkAndSendTokenOnLaunch() {
        // Small delay to ensure auth manager is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sendPushTokenIfNeeded()
        }
    }
}
