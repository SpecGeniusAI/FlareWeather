import SwiftUI
import CoreData
import UserNotifications
import UIKit
#if canImport(RevenueCat)
import RevenueCat
#endif

@main
struct FlareWeatherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = AuthManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    init() {
        // Request notification permissions on launch
        requestNotificationPermissions()
        #if canImport(RevenueCat)
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif
        
        // Use your SDK API Key (Public Key) from RevenueCat Dashboard
        // Get it from: RevenueCat Dashboard → Project Settings → API Keys → SDK API Keys
        // This is the PUBLIC key - safe to include in your app code
        // NOTE: Test API keys (test_...) use RevenueCat's Test Store, not App Store Connect
        // Use your PRODUCTION SDK API key to connect to real App Store Connect products
        
        let apiKey = "appl_TXJRcBaMmrBxzZdWktGaoPClEAE" // Replace with your SDK API Key from dashboard
        
        Purchases.configure(
            withAPIKey: apiKey
        )
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
                .task {
                    // Check current entitlements on app launch
                    await subscriptionManager.checkEntitlements()
                    
                    // Debug: Check RevenueCat offerings
                    await subscriptionManager.checkOfferings()
                }
                .onAppear {
                    // Send push token if user is logged in and token exists
                    AppDelegate.checkAndSendTokenOnLaunch()
                }
        }
    }
    
    private func requestNotificationPermissions() {
        // Check current authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                // Not determined - request permission
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if granted {
                        print("✅ Notification permissions granted")
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            AppDelegate.sendPushTokenIfNeeded()
                        }
                    } else if let error = error {
                        print("❌ Notification permission error: \(error.localizedDescription)")
                    } else {
                        print("⚠️ Notification permissions denied")
                    }
                }
            } else if settings.authorizationStatus == .authorized {
                // Already authorized - ALWAYS re-register to ensure token is sent to backend
                // This is critical: if user already granted permission, we need to re-register
                // to get the token and send it to backend
                print("✅ Notification permissions already authorized - re-registering to ensure token is sent")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                // Try multiple times with delays to ensure token is sent
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AppDelegate.sendPushTokenIfNeeded()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    AppDelegate.sendPushTokenIfNeeded()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    AppDelegate.sendPushTokenIfNeeded()
                }
            } else {
                print("⚠️ Notification permissions status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
}
