import SwiftUI
import CoreData
#if canImport(RevenueCat)
import RevenueCat
#endif

@main
struct FlareWeatherApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = AuthManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    init() {
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
        }
    }
}
