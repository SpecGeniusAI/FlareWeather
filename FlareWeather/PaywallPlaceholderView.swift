import SwiftUI

struct PaywallPlaceholderView: View {
    var onStartFreeWeek: () -> Void
    
    private let benefits = [
        "Daily insight tuned to your diagnoses",
        "Weekly weather outlook with pacing cues",
        "Where you feel it most (pressure, humidity, storms)",
        "Gentle alerts before major shifts"
    ]
    
    var body: some View {
        RevenueCatPaywallPlaceholder {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("Your personalized insight plan is ready")
                        .font(.interTitle)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.adaptiveText)
                        .padding(.horizontal)
                    
                    Text("Unlock the full experience with daily guidance, weekly planning, and tailored weather intel.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                            Text(benefit)
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .cardStyle()
                    }
                }
                .padding(.horizontal, 16)
                
                Button(action: onStartFreeWeek) {
                    Text("Start My Free Week")
                        .frame(maxWidth: .infinity)
                        .font(.interBody.bold())
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationTitle("Your Personal Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RevenueCatPaywallPlaceholder<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(Color.adaptiveText)
                    .padding(.top, 32)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 8)
                
                content()
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    PaywallPlaceholderView(onStartFreeWeek: {})
}

