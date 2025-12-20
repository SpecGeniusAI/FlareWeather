import SwiftUI

struct SubscriptionBannerView: View {
    @Environment(\.colorScheme) var colorScheme
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("Subscribe to get insights tailored uniquely to you")
                    .font(.interBody.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color(hex: "#4CAF50"))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SubscriptionBannerView(onTap: {})
}

