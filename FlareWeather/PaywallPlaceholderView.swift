import SwiftUI
import StoreKit

struct PaywallPlaceholderView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showSuccess = false
    @State private var isPurchasing = false
    @State private var selectedPlan: SubscriptionPlan = .monthly
    
    var onStartFreeWeek: () -> Void
    
    var body: some View {
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
                
                // Benefits - Properly formatted bullet points
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
                
                // Subscription Options
                if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color.adaptiveText)
                        Text("Loading subscription options...")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                    }
                    .padding(.vertical, 40)
                } else {
                    // Show subscription options (either loaded products or fallback for testing)
                    VStack(spacing: 12) {
                        // Plan Selection Area
                        VStack(spacing: 8) {
                            // Monthly Plan Option
                            if let monthlyProduct = subscriptionManager.monthlyProduct {
                                PlanSelectionRow(
                                    plan: .monthly,
                                    title: "Monthly",
                                    subtitle: subscriptionManager.formattedPrice(for: monthlyProduct),
                                    isSelected: selectedPlan == .monthly,
                                    isBestValue: false
                                ) {
                                    selectedPlan = .monthly
                                }
                            } else {
                                // Fallback for when products aren't loaded yet (e.g., TestFlight)
                                PlanSelectionRow(
                                    plan: .monthly,
                                    title: "Monthly",
                                    subtitle: "$2.99/month — 7 day free trial",
                                    isSelected: selectedPlan == .monthly,
                                    isBestValue: false
                                ) {
                                    selectedPlan = .monthly
                                }
                            }
                            
                            // Yearly Plan Option
                            if let yearlyProduct = subscriptionManager.yearlyProduct {
                                PlanSelectionRow(
                                    plan: .yearly,
                                    title: "Yearly",
                                    subtitle: "\(yearlyProduct.displayPrice)/year",
                                    isSelected: selectedPlan == .yearly,
                                    isBestValue: true
                                ) {
                                    selectedPlan = .yearly
                                }
                            } else {
                                // Fallback for when products aren't loaded yet
                                PlanSelectionRow(
                                    plan: .yearly,
                                    title: "Yearly",
                                    subtitle: "$19.99/year",
                                    isSelected: selectedPlan == .yearly,
                                    isBestValue: true
                                ) {
                                    selectedPlan = .yearly
                                }
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
                        
                        // Restore Purchases Link
                        Button(action: {
                            Task {
                                await subscriptionManager.restore()
                                if subscriptionManager.isSubscribed {
                                    onStartFreeWeek()
                                }
                            }
                        }) {
                            Text("Restore Purchases")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveMuted)
                        }
                        .padding(.top, 2)
                        
                        // Error Message
                        if let errorMessage = subscriptionManager.errorMessage {
                            Text(errorMessage)
                                .font(.interCaption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                        }
                        
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
            .padding(.bottom, 24)
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationTitle("Your Personal Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await subscriptionManager.fetchProducts()
        }
    }
    
    private func handleSubscribe() async {
        isPurchasing = true
        subscriptionManager.errorMessage = nil
        
        // Debug logging
        print("🔘 Subscribe tapped for plan: \(selectedPlan)")
        print("   Available products: \(subscriptionManager.products.count)")
        print("   Monthly product: \(subscriptionManager.monthlyProduct?.id ?? "nil")")
        print("   Yearly product: \(subscriptionManager.yearlyProduct?.id ?? "nil")")
        
        let product: Product?
        if selectedPlan == .monthly {
            product = subscriptionManager.monthlyProduct
        } else {
            product = subscriptionManager.yearlyProduct
        }
        
        guard let productToPurchase = product else {
            let planName = selectedPlan == .monthly ? "fw_plus_monthly" : "fw_plus_yearly"
            print("❌ Product not available for plan: \(planName)")
            print("   This usually means:")
            print("   1. Products not loaded from App Store Connect")
            print("   2. Product IDs don't match exactly")
            print("   3. Products not approved/available in sandbox")
            
            // Try fetching products again if they're not loaded
            if subscriptionManager.products.isEmpty {
                print("⚠️ No products loaded, fetching again...")
                await subscriptionManager.fetchProducts()
                // Retry after fetch
                if selectedPlan == .monthly, let monthly = subscriptionManager.monthlyProduct {
                    let success = await subscriptionManager.purchase(monthly)
                    if success {
                        withAnimation { showSuccess = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onStartFreeWeek()
                        }
                        isPurchasing = false
                        return
                    }
                } else if selectedPlan == .yearly, let yearly = subscriptionManager.yearlyProduct {
                    let success = await subscriptionManager.purchase(yearly)
                    if success {
                        withAnimation { showSuccess = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onStartFreeWeek()
                        }
                        isPurchasing = false
                        return
                    }
                }
            }
            
            subscriptionManager.errorMessage = "Selected plan not available. Please check your connection and try again."
            isPurchasing = false
            return
        }
        
        let success = await subscriptionManager.purchase(productToPurchase)
        
        if success {
            withAnimation {
                showSuccess = true
            }
            
            // Navigate to account creation after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onStartFreeWeek()
            }
        }
        
        isPurchasing = false
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
        // Bright green for dark mode, same green as "low flare risk" for light mode
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
