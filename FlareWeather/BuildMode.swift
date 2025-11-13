import Foundation
import StoreKit

// MARK: - Cached Build Mode Values
/// Cached value for TestFlight detection (initialized once)
private var cachedIsTestFlight: Bool? = nil
private var isTestFlightInitialized = false

/// Cached value for production detection (initialized once)
private var cachedIsProduction: Bool? = nil
private var isProductionInitialized = false

// MARK: - Build Mode Detection
/// Detects if the app is running in TestFlight or debug mode
/// 
/// Uses StoreKit 2's AppTransaction.shared (iOS 15.0+).
/// Since app targets iOS 18.5, StoreKit 2 is always available.
var isTestFlightOrDebug: Bool {
    #if DEBUG
    return true
    #else
    // Return cached value if available
    if isTestFlightInitialized, let cached = cachedIsTestFlight {
        return cached
    }
    
    // Use receipt URL to detect TestFlight (more reliable than StoreKit 2 environment)
    // TestFlight builds have sandboxReceipt in the path
    if let receiptURL = Bundle.main.appStoreReceiptURL {
        let isTestFlight = receiptURL.path.contains("sandboxReceipt")
        cachedIsTestFlight = isTestFlight
        isTestFlightInitialized = true
        return isTestFlight
    } else {
        // No receipt URL means not from App Store/TestFlight
        // Could be debug build or ad-hoc distribution
        cachedIsTestFlight = false
        isTestFlightInitialized = true
        return false
    }
    #endif
}

/// Detects if the app is running in production (App Store)
///
/// Uses StoreKit 2's AppTransaction.shared (iOS 15.0+).
/// Since app targets iOS 18.5, StoreKit 2 is always available.
var isProductionBuild: Bool {
    #if DEBUG
    return false
    #else
    // Return cached value if available
    if isProductionInitialized, let cached = cachedIsProduction {
        return cached
    }
    
    // Use receipt URL to detect App Store production
    // Production App Store builds have a receipt but not sandboxReceipt
    if let receiptURL = Bundle.main.appStoreReceiptURL {
        let isProduction = !receiptURL.path.contains("sandboxReceipt")
        cachedIsProduction = isProduction
        isProductionInitialized = true
        return isProduction
    } else {
        // No receipt URL means not from App Store
        cachedIsProduction = false
        isProductionInitialized = true
        return false
    }
    #endif
}

