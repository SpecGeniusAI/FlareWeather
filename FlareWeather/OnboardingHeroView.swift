import SwiftUI

struct OnboardingHeroView: View {
    @Environment(\.colorScheme) var colorScheme
    var onBack: () -> Void
    var onContinue: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.darkBackground : Color.primaryBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Back button - top left
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.interBody)
                        }
                        .foregroundColor(Color.adaptiveText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                Image(colorScheme == .dark ? "LogoLight" : "LogoDark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
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
    OnboardingHeroView(onBack: {}, onContinue: {})
        .environment(\.colorScheme, .light)
}

