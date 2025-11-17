import Foundation
import SwiftUI

// MARK: - Subscription Manager
/// Manages subscription status and premium feature access
@MainActor
class SubscriptionManager: ObservableObject {
    @Published var hasPlus: Bool = false
    @Published var isTestFlightBuild: Bool = false
    
    init() {
        checkSubscriptionStatus()
    }
    
    /// Check subscription status (TestFlight unlock or real subscription)
    func checkSubscriptionStatus() {
        // Check if this is a TestFlight or debug build
        isTestFlightBuild = isTestFlightOrDebug
        
        if isTestFlightBuild {
            // 🔓 Unlock all premium features for beta testing
            hasPlus = true
            print("🧪 TestFlight build detected — FlareWeather Plus unlocked")
        } else {
            // 🚧 Production build — check real subscription status
            // TODO: Implement RevenueCat or StoreKit integration
            hasPlus = false
            print("🏪 Production build — subscription required")
        }
    }
    
    /// Check if user has access to premium features
    var hasPremiumAccess: Bool {
        return hasPlus
    }
    
    /// Get subscription status description for UI
    var statusDescription: String {
        if isTestFlightBuild {
            return "BETA • Plus features unlocked"
        } else if hasPlus {
            return "FlareWeather Plus Active"
        } else {
            return "Upgrade to FlareWeather Plus"
        }
    }
}

