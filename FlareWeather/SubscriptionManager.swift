import Foundation
import SwiftUI
import StoreKit
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Subscription plan types (for compatibility)
enum SubscriptionPlan: String, Codable {
    case none
    case monthly
    case yearly
}

/// RevenueCat Subscription Manager
/// Modern RevenueCat API with StoreKit fallback
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    #if canImport(RevenueCat)
    // RevenueCat properties
    @Published var customerInfo: CustomerInfo?
    @Published var currentOffering: Offering?
    #else
    @Published var customerInfo: Any? = nil
    @Published var currentOffering: Any? = nil
    #endif
    
    // Published variables
    @Published var isProUser: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Legacy compatibility properties
    @Published var isSubscribed: Bool = false
    @Published var isPro: Bool = false
    @Published var currentPlan: SubscriptionPlan = .none
    
    // StoreKit fallback (for when RevenueCat not available)
    @Published var products: [Product] = []
    
    // Entitlement ID - must match RevenueCat dashboard exactly
    private let entitlementID = "FlareWeather Pro"
    
    // StoreKit transaction observer (always needed for fallback purchases)
    private var transactionUpdateTask: Task<Void, Never>?
    
    private init() {
        // Always set up Transaction.updates listener (needed for StoreKit fallback)
        observeStoreKitTransactions()
        
        #if canImport(RevenueCat)
        // Set up customerInfoStream listener
        listenForChanges()
        
        // Initial fetch
        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }
        #else
        // Fallback: Use StoreKit
        Task {
            await fetchProducts()
            await checkEntitlementsViaStoreKit()
        }
        #endif
    }
    
    // MARK: - StoreKit Transaction Observer
    
    /// Observe StoreKit transaction updates (always set up for fallback purchases)
    private func observeStoreKitTransactions() {
        transactionUpdateTask = Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await transaction.finish()
                    #if canImport(RevenueCat)
                    // Refresh RevenueCat customer info when transaction updates
                    await refreshCustomerInfo()
                    #else
                    // Check entitlements via StoreKit
                    await checkEntitlementsViaStoreKit()
                    #endif
                } catch {
                    print("❌ Transaction update error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - RevenueCat Methods
    
    #if canImport(RevenueCat)
    /// Fetch RevenueCat offerings
    func fetchOfferings() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Force fetch from network (bypass cache) to get latest configuration
            let offerings = try await Purchases.shared.offerings()
            print("📦 All offerings: \(offerings.all.keys.joined(separator: ", "))")
            
            // Log all offerings for debugging
            if !offerings.all.isEmpty {
                print("📦 Available offerings in dashboard:")
                for (key, offering) in offerings.all {
                    print("   - \(key): \(offering.identifier) - \(offering.availablePackages.count) packages")
                    for package in offering.availablePackages {
                        print("     Package: \(package.identifier) → Product: \(package.storeProduct.productIdentifier)")
                    }
                }
            }
            
            currentOffering = offerings.current
            
            if currentOffering == nil {
                print("⚠️ No current offering found")
                print("⚠️ Available offerings: \(offerings.all.keys.joined(separator: ", "))")
                if offerings.all.isEmpty {
                    errorMessage = "No offerings configured. Please create an offering in RevenueCat dashboard."
                } else {
                    errorMessage = "No current offering set. Please set 'default' as the current offering in RevenueCat dashboard."
                }
            } else {
                print("✅ Fetched offering: \(currentOffering?.identifier ?? "unknown")")
                print("✅ Packages in offering: \(currentOffering?.availablePackages.map { $0.identifier } ?? [])")
                
                if currentOffering?.availablePackages.isEmpty == true {
                    print("⚠️ Offering has no packages!")
                    errorMessage = "Offering has no packages. Please add packages ($rc_monthly, $rc_annual) to your offering in RevenueCat dashboard."
                } else {
                    // Success - clear any previous errors
                    errorMessage = nil
                }
            }
        } catch {
            print("❌ Error fetching offerings: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            
            // Extract more specific error information
            let errorString = String(describing: error)
            if errorString.contains("no products registered") {
                errorMessage = "Products not linked to offering. In RevenueCat dashboard: 1) Create products (fw_plus_monthly, fw_plus_yearly), 2) Create offering 'default', 3) Add packages ($rc_monthly, $rc_annual) to the offering."
            } else {
                errorMessage = "Unable to load subscription options: \(error.localizedDescription)"
            }
        }
    }
    
    /// Purchase a RevenueCat package
    func purchase(package: Package) async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let (_, info, _) = try await Purchases.shared.purchase(package: package)
            customerInfo = info
            updateEntitlementStatus(from: info)
            print("✅ Purchase successful")
        } catch {
            print("❌ Purchase failed: \(error)")
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("cancelled") || errorDescription.contains("cancel") {
                errorMessage = "Purchase cancelled"
            } else if errorDescription.contains("not available") {
                errorMessage = "Product not available"
            } else {
                errorMessage = "Purchase failed. Please try again."
            }
        }
    }
    
    /// Refresh customer info and entitlement status
    func refreshCustomerInfo() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            updateEntitlementStatus(from: info)
            print("✅ Customer info refreshed - isProUser: \(isProUser)")
        } catch {
            print("❌ Error fetching customer info: \(error)")
            errorMessage = "Unable to load subscription status. Please try again."
        }
    }
    
    /// Update entitlement status from CustomerInfo
    private func updateEntitlementStatus(from info: CustomerInfo) {
        isProUser = info.entitlements[entitlementID]?.isActive == true
        
        // Update legacy compatibility
        isPro = isProUser
        isSubscribed = isProUser
        
        // Determine plan type
        if isProUser {
            if let activeEntitlement = info.entitlements[entitlementID] {
                let productIdentifier = activeEntitlement.productIdentifier
                if productIdentifier.contains("yearly") || productIdentifier.contains("annual") {
                    currentPlan = .yearly
                } else if productIdentifier.contains("monthly") {
                    currentPlan = .monthly
                } else {
                    currentPlan = .yearly // Default
                }
            }
        } else {
            currentPlan = .none
        }
    }
    
    /// Listen for CustomerInfo updates via customerInfoStream
    private func listenForChanges() {
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run {
                    self?.customerInfo = info
                    self?.updateEntitlementStatus(from: info)
                }
            }
        }
    }
    #endif
    
    // MARK: - Public Methods (Always Available)
    
    /// Restore purchases (always available, works with RevenueCat or StoreKit)
    func restore() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        #if canImport(RevenueCat)
        do {
            let info = try await Purchases.shared.restorePurchases()
            customerInfo = info
            updateEntitlementStatus(from: info)
            
            if !isProUser {
                errorMessage = "No active subscription found"
            } else {
                print("✅ Purchases restored")
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Restore failed: \(error)")
        }
        #else
        // Fallback: Use StoreKit restore
        do {
            try await AppStore.sync()
            await checkEntitlementsViaStoreKit()
            
            if !isSubscribed {
                errorMessage = "No active subscription found"
            } else {
                print("✅ Purchases restored")
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Restore failed: \(error)")
        }
        #endif
    }
    
    // MARK: - Legacy Compatibility Methods
    
    /// Legacy: Check entitlements (maps to refreshCustomerInfo)
    func checkEntitlements() async {
        #if canImport(RevenueCat)
        await refreshCustomerInfo()
        #else
        await checkEntitlementsViaStoreKit()
        #endif
    }
    
    /// Legacy: Purchase with Product (for backward compatibility)
    func purchase(_ product: Product) async -> Bool {
        #if canImport(RevenueCat)
        // Try to find matching package
        var offering = currentOffering
        if offering == nil {
            // Fetch offerings if not loaded
            await fetchOfferings()
            offering = currentOffering
        }
        
        guard let offering = offering else {
            errorMessage = "Subscription options not available"
            return false
        }
        
        // Find package that matches product ID
        if let package = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == product.id }) {
            await purchase(package: package)
            return isProUser
        } else {
            errorMessage = "Package not found for product"
            return false
        }
        #else
        return await purchaseViaStoreKit(product)
        #endif
    }
    
    /// Legacy: Upgrade to yearly
    func upgradeToYearly() async -> Bool {
        #if canImport(RevenueCat)
        var offering = currentOffering
        if offering == nil {
            await fetchOfferings()
            offering = currentOffering
        }
        
        guard let offering = offering else {
            errorMessage = "Subscription options not available"
            return false
        }
        
        // Find yearly package ($rc_annual)
        if let yearlyPackage = offering.availablePackages.first(where: { 
            $0.identifier == "$rc_annual" || 
            $0.storeProduct.productIdentifier.contains("yearly") ||
            $0.storeProduct.productIdentifier.contains("annual")
        }) {
            await purchase(package: yearlyPackage)
            return isProUser
        } else {
            errorMessage = "Yearly plan not available"
            return false
        }
        #else
        guard let yearlyProduct = products.first(where: { $0.id.contains("yearly") }) else {
            errorMessage = "Yearly plan not available"
            return false
        }
        return await purchase(yearlyProduct)
        #endif
    }
    
    // MARK: - StoreKit Fallback (when RevenueCat not available)
    
    #if !canImport(RevenueCat)
    /// Fetch StoreKit products (fallback)
    func fetchProducts() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let productIDs = ["fw_plus_monthly", "fw_plus_yearly"]
            let storeProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.products = storeProducts.sorted { product1, product2 in
                    if product1.id.contains("yearly") { return true }
                    if product2.id.contains("yearly") { return false }
                    return false
                }
            }
            
            print("✅ Fetched \(storeProducts.count) StoreKit products")
        } catch {
            print("❌ Failed to fetch StoreKit products: \(error)")
            errorMessage = "Unable to load subscription products. Please try again."
        }
    }
    
    /// Purchase via StoreKit (fallback)
    /// Note: Transaction.updates listener is set up in init() via observeStoreKitTransactions()
    private func purchaseViaStoreKit(_ product: Product) async -> Bool {
        // Transaction.updates listener is active (set up in init())
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkEntitlementsViaStoreKit()
                return isSubscribed
                
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
            print("❌ Purchase failed: \(error)")
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }
    
    /// Check entitlements via StoreKit (fallback)
    private func checkEntitlementsViaStoreKit() async {
        var hasEntitlement = false
        var detectedPlan: SubscriptionPlan = .none
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID.contains("monthly") || transaction.productID.contains("yearly") {
                    hasEntitlement = true
                    
                    if transaction.productID.contains("yearly") {
                        detectedPlan = .yearly
                    } else if transaction.productID.contains("monthly") {
                        detectedPlan = .monthly
                    }
                }
            } catch {
                print("❌ Entitlement verification error: \(error.localizedDescription)")
            }
        }
        
        isSubscribed = hasEntitlement
        isPro = hasEntitlement
        isProUser = hasEntitlement
        currentPlan = detectedPlan
    }
    #endif
    
    // MARK: - Helper Methods (Always Available)
    
    /// Verify transaction signature (always available for transaction observer)
    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// Format price with intro offer (for custom UI)
    func formattedPrice(for product: Product) -> String {
        if product.id.contains("monthly"), let subscription = product.subscription,
           let intro = subscription.introductoryOffer {
            if intro.paymentMode == .freeTrial {
                return "\(product.displayPrice)/month — 7 day free trial"
            }
        }
        return product.displayPrice
    }
    
    /// Get monthly product (legacy)
    var monthlyProduct: Product? {
        products.first { $0.id.contains("monthly") }
    }
    
    /// Get yearly product (legacy)
    var yearlyProduct: Product? {
        products.first { $0.id.contains("yearly") }
    }
    
    /// Legacy compatibility
    var hasPremiumAccess: Bool {
        return isProUser
    }
    
    /// Legacy compatibility
    var hasPlus: Bool {
        return isProUser
    }
    
    /// Debug: Check RevenueCat offerings
    func checkOfferings() async {
        #if canImport(RevenueCat)
        print("🔄 Force refreshing offerings from RevenueCat...")
        await fetchOfferings()
        if let offering = currentOffering {
            print("📦 RevenueCat Offerings:")
            print("   Current offering: \(offering.identifier)")
            print("   Available packages: \(offering.availablePackages.count)")
            for package in offering.availablePackages {
                print("     - \(package.identifier): \(package.storeProduct.productIdentifier) - \(package.storeProduct.localizedPriceString)")
            }
        } else {
            print("❌ No current offering found")
            print("   Error: \(errorMessage ?? "Unknown error")")
            print("   💡 Check RevenueCat dashboard:")
            print("      1. Products are attached to 'FlareWeather (App Store)'")
            print("      2. Offering 'default' is set as current")
            print("      3. Packages are linked to products")
            print("      4. App Store Connect API key is connected")
        }
        #else
        print("⚠️ RevenueCat not available - add package via SPM")
        #endif
    }
}
