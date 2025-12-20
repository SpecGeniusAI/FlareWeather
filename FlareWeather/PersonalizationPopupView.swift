import SwiftUI

struct PersonalizationPopupView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var onGetPersonalInsights: () -> Void
    var onMaybeLater: () -> Void
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onMaybeLater()
                }
            
            // Popup Card
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your body deals with enough unpredictability.")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                        .multilineTextAlignment(.leading)
                    
                    Text("Subscribe to unlock insights tailored to your diagnoses, weather triggers, and sensitivities — not just general forecasts.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Buttons
                VStack(spacing: 12) {
                    // Button 1: Get my personal insights
                    Button(action: onGetPersonalInsights) {
                        Text("Get my personal insights")
                            .font(.interBody.weight(.semibold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#2d3240") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.adaptiveAccent)
                            .cornerRadius(12)
                    }
                    
                    // Button 2: Maybe Later
                    Button(action: onMaybeLater) {
                        Text("Maybe Later")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
            }
            .padding(24)
            .background(Color.adaptiveCardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    PersonalizationPopupView(
        onGetPersonalInsights: {},
        onMaybeLater: {}
    )
    .environmentObject(SubscriptionManager.shared)
}

