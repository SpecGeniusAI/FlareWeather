import SwiftUI
import RevenueCat
import RevenueCatUI

struct WeeklyInsightGateView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false
    @State private var offering: Offering?
    
    // The actual weekly insight content view
    let weeklyInsightContent: () -> AnyView
    
    init(@ViewBuilder weeklyInsightContent: @escaping () -> some View) {
        self.weeklyInsightContent = { AnyView(weeklyInsightContent()) }
    }
    
    var body: some View {
        if subscriptionManager.isPro {
            // Show full weekly insight content
            weeklyInsightContent()
        } else {
            // Show preview with upgrade button
            VStack(spacing: 16) {
                // Sample preview (you can customize this)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly Insight Preview")
                        .font(.interHeadline)
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("Get personalized weekly weather outlooks with pacing cues tailored to your conditions.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.adaptiveCardBackground)
                .cornerRadius(12)
                
                Button("Unlock Full Weekly Outlook") {
                    showPaywall = true
                }
                .buttonStyle(.borderedProminent)
            }
            .sheet(isPresented: $showPaywall) {
                if let offering = offering {
                    PaywallView(offering: offering)
                        .onPurchaseCompleted { customerInfo in
                            Task {
                                await subscriptionManager.refreshCustomerInfo()
                            }
                            showPaywall = false
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
}

