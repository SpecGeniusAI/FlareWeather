import SwiftUI

struct AccessExpiredPopupView: View {
    let expired: Bool
    let logoutMessage: String?
    let onSubscribe: () -> Void
    let onLogout: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(expired ? "Free Access Has Ended" : "Access Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(expired 
                ? "Your free access period has ended. Subscribe to continue enjoying full insights, or logout to view basic insights."
                : "Full access is required for personalized insights. Subscribe to unlock all features, or logout to view basic insights.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button("Subscribe") {
                    onSubscribe()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Button("Logout") {
                        onLogout()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    if let message = logoutMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(maxWidth: 320)
    }
}

#Preview {
    AccessExpiredPopupView(
        expired: true,
        logoutMessage: "Logout to see basic insights",
        onSubscribe: {},
        onLogout: {}
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
