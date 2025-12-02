import SwiftUI
import StoreKit
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct PaywallPlaceholderView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    #if canImport(RevenueCat)
    @State private var packages: [Package] = []
    #else
    @State private var products: [Product] = []
    #endif
    @State private var purchaseErrorMessage: String? // For purchase errors (doesn't hide products)
    @State private var showSuccess = false
    @State private var isPurchasing = false
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var useRevenueCatPaywall = false // Toggle to test RevenueCat's built-in paywall
    
    var onStartFreeWeek: () -> Void
    
    var body: some View {
        #if canImport(RevenueCat) && canImport(RevenueCatUI)
        if useRevenueCatPaywall, let offering = subscriptionManager.currentOffering {
            // RevenueCat's built-in paywall (for testing)
            PaywallView(offering: offering)
                .onPurchaseCompleted { customerInfo in
                    Task {
                        subscriptionManager.customerInfo = customerInfo
                        await subscriptionManager.refreshCustomerInfo()
                        if subscriptionManager.isProUser {
                            onStartFreeWeek()
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Custom UI") {
                            useRevenueCatPaywall = false
                        }
                    }
                }
        } else {
            customPaywallView
        }
        #else
        customPaywallView
        #endif
    }
    
    private var customPaywallView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start Your 7-Day Free Trial")
                        .font(.interTitle)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Color.adaptiveText)
                        .padding(.top, 16)
                    
                    Text("Personalized daily and weekly insights tailored to your conditions.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 24)
                
                // Benefits
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                        Text("Daily insight tuned to your diagnoses")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                        Text("Weekly weather outlook with pacing cues")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                        Text("Where you feel it most (pressure, humidity, storms)")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                        Text("Gentle alerts before major shifts")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 24)
                
                // Content - Always show subscription options (with fallback prices)
                subscriptionOptionsView
            }
            .padding(.bottom, 24)
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationTitle("Your Personal Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if canImport(RevenueCat) && canImport(RevenueCatUI)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Test RC Paywall") {
                    useRevenueCatPaywall = true
                }
                .font(.caption)
            }
            #endif
        }
        .task {
            await loadOfferings()
        }
        .refreshable {
            await loadOfferings()
        }
        .onChange(of: subscriptionManager.currentOffering) { oldValue, newValue in
            #if canImport(RevenueCat) && canImport(RevenueCatUI)
            // Auto-switch to RevenueCat paywall if offering loads successfully
            if newValue != nil && packages.isEmpty && !useRevenueCatPaywall {
                print("✅ Offering loaded - you can test RevenueCat paywall by tapping 'Test RC Paywall' button")
            }
            #endif
        }
    }
    
    // MARK: - Loading
    
    private func loadOfferings() async {
        #if canImport(RevenueCat)
        await subscriptionManager.fetchOfferings()
        
        await MainActor.run {
            if let offering = subscriptionManager.currentOffering {
                print("📦 Offering found: \(offering.identifier)")
                print("📦 Available packages: \(offering.availablePackages.map { $0.identifier })")
                
                if offering.availablePackages.isEmpty {
                    print("⚠️ Offering has no available packages - falling back to StoreKit")
                    // Fallback to StoreKit if RevenueCat offering has no packages
                    Task {
                        await loadStoreKitProductsAsFallback()
                    }
                } else {
                    // Sort packages: yearly first, then monthly
                    let sortedPackages = offering.availablePackages.sorted { package1, package2 in
                        if package1.identifier == "$rc_annual" || package1.storeProduct.productIdentifier.contains("yearly") {
                            return true
                        }
                        if package2.identifier == "$rc_annual" || package2.storeProduct.productIdentifier.contains("yearly") {
                            return false
                        }
                        return false
                    }
                    self.packages = sortedPackages
                    self.purchaseErrorMessage = nil
                    subscriptionManager.errorMessage = nil
                    print("✅ Packages loaded: \(sortedPackages.map { $0.identifier })")
                }
            } else {
                print("⚠️ No current offering found - falling back to StoreKit")
                print("⚠️ SubscriptionManager errorMessage: \(subscriptionManager.errorMessage ?? "nil")")
                
                // Fallback to StoreKit if RevenueCat fails
                Task {
                    await loadStoreKitProductsAsFallback()
                }
            }
        }
        #else
        // Fallback: Load StoreKit products
        await loadStoreKitProductsAsFallback()
        #endif
    }
    
    // MARK: - StoreKit Fallback
    
    private func loadStoreKitProductsAsFallback() async {
        do {
            let productIDs = ["fw_plus_monthly", "fw_plus_yearly"]
            let fetchedProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                let sortedProducts = fetchedProducts.sorted { product1, product2 in
                    product1.id == "fw_plus_yearly" ? true : (product2.id == "fw_plus_yearly" ? false : false)
                }
                #if canImport(RevenueCat)
                // Store products for fallback purchase
                self.subscriptionManager.products = sortedProducts
                print("⚠️ Using StoreKit fallback - products: \(sortedProducts.map { $0.id })")
                #else
                self.products = sortedProducts
                #endif
                self.subscriptionManager.products = sortedProducts
                self.subscriptionManager.errorMessage = nil
                print("✅ StoreKit products loaded: \(sortedProducts.map { $0.id })")
            }
        } catch {
            print("❌ Failed to load StoreKit products: \(error)")
            await MainActor.run {
                #if canImport(RevenueCat)
                // Keep RevenueCat error message if StoreKit also fails
                if self.packages.isEmpty && self.purchaseErrorMessage == nil {
                    self.purchaseErrorMessage = "Plans unavailable. Please ensure StoreKit config is selected in Xcode scheme."
                }
                #else
                if self.products.isEmpty {
                    self.purchaseErrorMessage = "Plans unavailable. Please try again later."
                }
                #endif
            }
        }
    }
    
    // MARK: - Subscription Options View
    
    @ViewBuilder
    private var subscriptionOptionsView: some View {
        VStack(spacing: 12) {
            // Show fallback message if packages/products failed to load
            #if canImport(RevenueCat)
            let hasPackages = !packages.isEmpty
            #else
            let hasPackages = !products.isEmpty
            #endif
            
            #if canImport(RevenueCat)
            // Check if we have StoreKit products as fallback
            let hasStoreKitProducts = !subscriptionManager.products.isEmpty
            #else
            let hasStoreKitProducts = false
            #endif
            
            if !hasPackages && !hasStoreKitProducts {
                VStack(spacing: 12) {
                    Text(purchaseErrorMessage ?? "Plans unavailable. Please try again later.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                    
                    #if canImport(RevenueCat)
                    Text("Tip: Ensure 'Products.storekit' is selected in your Xcode scheme (Product → Scheme → Edit Scheme → Run → StoreKit Configuration)")
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    #endif
                    
                    Button(action: {
                        Task {
                            await loadOfferings()
                        }
                    }) {
                        Text("Retry")
                            .font(.interBody.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#888779"))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                // Purchase Error Banner (if any, doesn't hide products)
                if let purchaseError = purchaseErrorMessage {
                    VStack(spacing: 8) {
                        Text(purchaseError)
                            .font(.interBody)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        Button(action: {
                            purchaseErrorMessage = nil
                        }) {
                            Text("Dismiss")
                                .font(.interCaption)
                                .foregroundColor(Color.adaptiveMuted)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }
                
                // Plan Selection
                VStack(spacing: 8) {
                    // Monthly Plan
                    PlanSelectionRow(
                        plan: .monthly,
                        title: "Monthly",
                        subtitle: monthlyPriceString,
                        isSelected: selectedPlan == .monthly,
                        isBestValue: false
                    ) {
                        selectedPlan = .monthly
                    }
                    
                    // Yearly Plan
                    PlanSelectionRow(
                        plan: .yearly,
                        title: "Yearly",
                        subtitle: yearlyPriceString,
                        isSelected: selectedPlan == .yearly,
                        isBestValue: true
                    ) {
                        selectedPlan = .yearly
                    }
                }
                .padding(.horizontal, 16)
                
                // Subscribe Button
                Button(action: {
                    Task {
                        await handleSubscribe()
                    }
                }) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(Color.adaptiveText)
                        } else {
                            Text("Subscribe")
                                .font(.interBody.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isPurchasing || showSuccess)
                .padding(.horizontal, 32)
                .padding(.top, 2)
                
                // Restore Purchases
                Button(action: {
                    Task {
                        await subscriptionManager.restore()
                        if subscriptionManager.isProUser {
                            onStartFreeWeek()
                        }
                    }
                }) {
                    Text("Restore Purchases")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                }
                .padding(.top, 2)
                
                // Success Message
                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Subscription activated!")
                            .font(.interBody)
                            .foregroundColor(.green)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }
    
    // MARK: - Purchase Handling
    
    private func handleSubscribe() async {
        // Clear any previous purchase errors
        await MainActor.run {
            purchaseErrorMessage = nil
            isPurchasing = true
        }
        
        #if canImport(RevenueCat)
        // Try RevenueCat packages first
        if !packages.isEmpty {
            let packageIdentifier = selectedPlan == .monthly ? "$rc_monthly" : "$rc_annual"
            
            guard let packageToPurchase = packages.first(where: { 
                $0.identifier == packageIdentifier ||
                (selectedPlan == .monthly && ($0.identifier.contains("monthly") || $0.storeProduct.productIdentifier.contains("monthly"))) ||
                (selectedPlan == .yearly && ($0.identifier.contains("annual") || $0.storeProduct.productIdentifier.contains("yearly") || $0.storeProduct.productIdentifier.contains("annual")))
            }) else {
                await MainActor.run {
                    isPurchasing = false
                    purchaseErrorMessage = "The \(selectedPlan == .monthly ? "monthly" : "yearly") plan is not available. Please try again or refresh the page."
                }
                return
            }
            
            print("✅ Found RevenueCat package: \(packageToPurchase.identifier) - \(packageToPurchase.storeProduct.localizedPriceString)")
            
            await subscriptionManager.purchase(package: packageToPurchase)
            
            await MainActor.run {
                isPurchasing = false
                if subscriptionManager.isProUser {
                    withAnimation {
                        showSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onStartFreeWeek()
                    }
                } else {
                    // If purchase fails, show error banner but keep packages visible
                    if let purchaseError = subscriptionManager.errorMessage {
                        purchaseErrorMessage = purchaseError
                    } else {
                        purchaseErrorMessage = "Purchase failed. Please try again."
                    }
                }
            }
        } else {
            // Fallback: Use StoreKit products directly (won't track in RevenueCat dashboard)
            print("⚠️ Using StoreKit fallback for purchase (won't track in RevenueCat)")
            let productID = selectedPlan == .monthly ? "fw_plus_monthly" : "fw_plus_yearly"
            guard let productToPurchase = subscriptionManager.products.first(where: { $0.id == productID }) else {
                await MainActor.run {
                    isPurchasing = false
                    purchaseErrorMessage = "The \(selectedPlan == .monthly ? "monthly" : "yearly") plan is not available. Please try again or refresh the page."
                }
                return
            }
            
            let success = await subscriptionManager.purchase(productToPurchase)
            
            await MainActor.run {
                isPurchasing = false
                if success {
                    withAnimation {
                        showSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onStartFreeWeek()
                    }
                } else {
                    if let purchaseError = subscriptionManager.errorMessage {
                        purchaseErrorMessage = purchaseError
                    } else {
                        purchaseErrorMessage = "Purchase failed. Please try again."
                    }
                }
            }
        }
        #else
        // Fallback: Use StoreKit products
        let productID = selectedPlan == .monthly ? "fw_plus_monthly" : "fw_plus_yearly"
        guard let productToPurchase = products.first(where: { $0.id == productID }) else {
            await MainActor.run {
                isPurchasing = false
                purchaseErrorMessage = "The \(selectedPlan == .monthly ? "monthly" : "yearly") plan is not available. Please try again or refresh the page."
            }
            return
        }
        
        let success = await subscriptionManager.purchase(productToPurchase)
        
        await MainActor.run {
            isPurchasing = false
            if success {
                withAnimation {
                    showSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onStartFreeWeek()
                }
            } else {
                if let purchaseError = subscriptionManager.errorMessage {
                    purchaseErrorMessage = purchaseError
                } else {
                    purchaseErrorMessage = "Purchase failed. Please try again."
                }
            }
        }
        #endif
    }
    
    // MARK: - Price Helpers
    
    private var monthlyPriceString: String {
        #if canImport(RevenueCat)
        // Try RevenueCat packages first
        if let monthlyPackage = packages.first(where: { 
            $0.identifier == "$rc_monthly" || 
            $0.storeProduct.productIdentifier.contains("monthly")
        }) {
            return monthlyPackage.storeProduct.localizedPriceString
        }
        // Fallback to StoreKit products
        if let product = subscriptionManager.products.first(where: { $0.id == "fw_plus_monthly" }) {
            return subscriptionManager.formattedPrice(for: product)
        }
        return "$2.99/month — 7 day free trial"
        #else
        if let product = products.first(where: { $0.id == "fw_plus_monthly" }) {
            return subscriptionManager.formattedPrice(for: product)
        }
        return "$2.99/month — 7 day free trial"
        #endif
    }
    
    private var yearlyPriceString: String {
        #if canImport(RevenueCat)
        // Try RevenueCat packages first
        if let yearlyPackage = packages.first(where: { 
            $0.identifier == "$rc_annual" || 
            $0.storeProduct.productIdentifier.contains("yearly") ||
            $0.storeProduct.productIdentifier.contains("annual")
        }) {
            return "\(yearlyPackage.storeProduct.localizedPriceString)/year"
        }
        // Fallback to StoreKit products
        if let product = subscriptionManager.products.first(where: { $0.id == "fw_plus_yearly" }) {
            return "\(product.displayPrice)/year"
        }
        return "$19.99/year"
        #else
        if let product = products.first(where: { $0.id == "fw_plus_yearly" }) {
            return "\(product.displayPrice)/year"
        }
        return "$19.99/year"
        #endif
    }
}

struct BenefitRow: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.interBody)
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#888779"))
                .frame(width: 24)
            Text(text)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .cardStyle()
    }
}

struct PlanSelectionRow: View {
    @Environment(\.colorScheme) var colorScheme
    let plan: SubscriptionPlan
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void
    
    private var accentColor: Color {
        colorScheme == .dark ? Color.adaptiveMuted : Color(hex: "#888779")
    }
    
    private var savingsColor: Color {
        colorScheme == .dark ? Color(hex: "#4ECDC4") : Color(hex: "#1A6B5A")
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Radio button indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? accentColor : Color.adaptiveMuted, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 14, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.interHeadline)
                            .foregroundColor(Color.adaptiveText)
                        
                        if isBestValue {
                            Text("Yearly saves you 44%")
                                .font(.interCaption)
                                .fontWeight(.semibold)
                                .foregroundColor(savingsColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(savingsColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subtitle)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? accentColor.opacity(colorScheme == .dark ? 0.15 : 0.08) : Color.adaptiveCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? accentColor.opacity(colorScheme == .dark ? 0.4 : 0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallPlaceholderView(onStartFreeWeek: {})
        .environmentObject(SubscriptionManager.shared)
}
