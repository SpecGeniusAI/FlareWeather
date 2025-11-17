import SwiftUI

struct OnboardingHeroView: View {
    var onContinue: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.9)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: isVisible)
                
                VStack(spacing: 12) {
                    Text("Understand how weather may affect your symptoms.")
                        .font(.interTitle)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.adaptiveText)
                        .padding(.horizontal, 32)
                        .lineSpacing(6)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1), value: isVisible)
                    
                    Text("FlareWeather blends real-time weather patterns with your health profile to deliver calm, actionable guidance.")
                        .font(.interBody)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 40)
                        .lineSpacing(5)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 24)
                        .animation(.spring(response: 0.65, dampingFraction: 0.8).delay(0.2), value: isVisible)
                }
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .font(.interBody.bold())
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: isVisible)
            }
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

#Preview {
    OnboardingHeroView(onContinue: {})
        .environment(\.colorScheme, .light)
}

