import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallLauncherView: View {
    @State private var offering: Offering?
    @State private var showPaywall = false
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // Optional callback for when purchase completes (for onboarding flow)
    var onPurchaseCompleted: (() -> Void)? = nil
    
    // If true, shows paywall directly (for onboarding). If false, shows a button that opens paywall.
    var showDirectly: Bool = false
    
    var body: some View {
        Group {
            if showDirectly {
                // Show paywall directly (for onboarding flow)
                if let offering = offering {
                    PaywallView(offering: offering)
                        .onPurchaseCompleted { customerInfo in
                            // Update subscription status
                            Task {
                                await subscriptionManager.refreshCustomerInfo()
                            }
                            // Call completion handler if provided
                            onPurchaseCompleted?()
                        }
                } else {
                    VStack(spacing: 16) {
                        ProgressView("Loading…")
                        Text("Preparing subscription options...")
                            .font(.interCaption)
                            .foregroundColor(Color.adaptiveMuted)
                    }
                }
            } else {
                // Show button that opens paywall in sheet
                VStack {
                    Button("Upgrade to Flare Pro") {
                        showPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .sheet(isPresented: $showPaywall) {
                    if let offering = offering {
                        // RevenueCat hosted paywall
                        PaywallView(offering: offering)
                            .onPurchaseCompleted { customerInfo in
                                // Update subscription status
                                Task {
                                    await subscriptionManager.refreshCustomerInfo()
                                }
                                showPaywall = false
                                // Call completion handler if provided
                                onPurchaseCompleted?()
                            }
                    } else {
                        VStack(spacing: 16) {
                            ProgressView("Loading…")
                            Text("Preparing subscription options...")
                                .font(.interCaption)
                                .foregroundColor(Color.adaptiveMuted)
                        }
                    }
                }
            }
        }
        .task {
            do {
                let offerings = try await Purchases.shared.offerings()
                offering = offerings.current
            } catch {
                print("❌ Failed to load offering: \(error)")
            }
        }
    }
}

