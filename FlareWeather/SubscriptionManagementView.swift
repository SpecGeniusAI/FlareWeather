import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// Customer Center view for managing subscriptions
struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            #if canImport(RevenueCatUI)
            CustomerCenterView()
                .navigationTitle("Manage Subscription")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            #else
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("Subscription Management")
                    .font(.interHeadline)
                
                Text("Please add RevenueCat package to enable subscription management.")
                    .font(.interBody)
                    .foregroundColor(.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .navigationTitle("Manage Subscription")
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    SubscriptionManagementView()
}

