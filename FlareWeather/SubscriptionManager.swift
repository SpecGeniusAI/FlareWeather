import Foundation
import SwiftUI
import StoreKit

/// Subscription plan types
enum SubscriptionPlan: String, Codable {
    case none
    case monthly
    case yearly
}

/// StoreKit 2 Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var products: [Product] = []
    @Published var currentPlan: SubscriptionPlan = .none
    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Product IDs
    private let monthlyProductID = "fw_plus_monthly"
    private let yearlyProductID = "fw_plus_yearly"
    private let entitlementID = "plus"
    
    // AppStorage for persistence
    @AppStorage("currentPlan") private var storedPlan: String = SubscriptionPlan.none.rawValue
    
    private var updateListenerTask: Task<Void, Never>?
    
    init() {
        // Restore plan from AppStorage
        if let plan = SubscriptionPlan(rawValue: storedPlan) {
            currentPlan = plan
        }
        
        // Start listening for transaction updates
        updateListenerTask = observeTransactions()
        
        // Check current entitlements
        Task {
            await checkEntitlements()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    /// Observe transaction updates
    func observeTransactions() -> Task<Void, Never> {
        return Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await transaction.finish()
                    await checkEntitlements()
                } catch {
                    print("❌ Transaction update error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Fetch available subscription products
    func fetchProducts() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let productIDs = [monthlyProductID, yearlyProductID]
            let storeProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.products = storeProducts.sorted { product1, product2 in
                    // Yearly first, then monthly
                    if product1.id == yearlyProductID { return true }
                    if product2.id == yearlyProductID { return false }
                    return false
                }
            }
            
            print("✅ Fetched \(storeProducts.count) products")
            for product in storeProducts {
                print("   - \(product.id): \(product.displayPrice)")
            }
            
            // Log which products were found
            if storeProducts.isEmpty {
                print("⚠️ No products found! Check:")
                print("   1. Products created in App Store Connect with IDs: \(monthlyProductID), \(yearlyProductID)")
                print("   2. Products are in 'Ready to Submit' or approved status")
                print("   3. Products are in the 'FlareWeather Subscription' subscription group")
                print("   4. Testing with sandbox account in TestFlight")
            } else {
                let foundMonthly = storeProducts.contains { $0.id == monthlyProductID }
                let foundYearly = storeProducts.contains { $0.id == yearlyProductID }
                if !foundMonthly {
                    print("⚠️ Monthly product (\(monthlyProductID)) not found in fetched products")
                }
                if !foundYearly {
                    print("⚠️ Yearly product (\(yearlyProductID)) not found in fetched products")
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load subscription options. Please try again."
            }
            print("❌ Failed to fetch products: \(error.localizedDescription)")
        }
    }
    
    /// Purchase a subscription product
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkEntitlements()
                return true
                
            case .userCancelled:
                errorMessage = "Purchase cancelled"
                return false
                
            case .pending:
                errorMessage = "Purchase is pending approval"
                return false
                
            @unknown default:
                errorMessage = "Unknown purchase result"
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Restore previous purchases
    func restore() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            try await AppStore.sync()
            await checkEntitlements()
            
            if !isSubscribed {
                errorMessage = "No active subscription found"
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Restore error: \(error.localizedDescription)")
        }
    }
    
    /// Upgrade from monthly to yearly
    func upgradeToYearly() async -> Bool {
        guard let yearlyProduct = products.first(where: { $0.id == yearlyProductID }) else {
            errorMessage = "Yearly plan not available"
            return false
        }
        
        return await purchase(yearlyProduct)
    }
    
    /// Check current entitlements and update subscription status
    func checkEntitlements() async {
        var hasEntitlement = false
        var detectedPlan: SubscriptionPlan = .none
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if this transaction grants the "plus" entitlement
                if transaction.productID == monthlyProductID || transaction.productID == yearlyProductID {
                    hasEntitlement = true
                    
                    // Determine plan type
                    if transaction.productID == yearlyProductID {
                        detectedPlan = .yearly
                    } else if transaction.productID == monthlyProductID {
                        detectedPlan = .monthly
                    }
                }
            } catch {
                print("❌ Entitlement verification error: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isSubscribed = hasEntitlement
            self.currentPlan = detectedPlan
            self.storedPlan = detectedPlan.rawValue
        }
    }
    
    /// Verify transaction signature
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// Get monthly product
    var monthlyProduct: Product? {
        products.first { $0.id == monthlyProductID }
    }
    
    /// Get yearly product
    var yearlyProduct: Product? {
        products.first { $0.id == yearlyProductID }
    }
    
    /// Get intro offer for monthly plan (7-day free trial)
    var monthlyIntroOffer: Product.SubscriptionOffer? {
        guard let monthly = monthlyProduct,
              let subscription = monthly.subscription else {
            return nil
        }
        
        // Look for free trial intro offer
        return subscription.introductoryOffer
    }
    
    /// Format price with intro offer
    func formattedPrice(for product: Product) -> String {
        if product.id == monthlyProductID, let intro = monthlyIntroOffer {
            // Show intro offer pricing
            if intro.paymentMode == .freeTrial {
                return "\(product.displayPrice)/month — 7 day free trial"
            }
        }
        
        return product.displayPrice
    }
    
    /// Format subscription period
    private func formatPeriod(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return "\(period.value) Day\(period.value > 1 ? "s" : "")"
        case .week:
            return "\(period.value) Week\(period.value > 1 ? "s" : "")"
        case .month:
            return "\(period.value) Month\(period.value > 1 ? "s" : "")"
        case .year:
            return "\(period.value) Year\(period.value > 1 ? "s" : "")"
        @unknown default:
            return "\(period.value) period"
        }
    }
    
    /// Check if user has premium access (legacy compatibility)
    var hasPremiumAccess: Bool {
        return isSubscribed
    }
    
    /// Legacy compatibility
    var hasPlus: Bool {
        return isSubscribed
    }
}
