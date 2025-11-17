import SwiftUI

struct OnboardingValueView: View {
    struct ValueCard: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }
    
    private let cards: [ValueCard] = [
        .init(icon: "sparkles", title: "Daily Insight", description: "Gentle, day-by-day guidance that matches the forecast."),
        .init(icon: "calendar", title: "Weekly Outlook", description: "See when weather swings may ask for extra pacing."),
        .init(icon: "person.fill.checkmark", title: "Personalized to You", description: "Tailored to your diagnoses and sensitivities.")
    ]
    
    var onContinue: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("What you’ll receive")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                    
                    Text("FlareWeather keeps an eye on pressure, humidity, temperature, and storm fronts so you can plan with confidence.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                VStack(spacing: 18) {
                    ForEach(cards) { card in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: card.icon)
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(Color.adaptiveCardBackground.opacity(0.6))
                                )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.title)
                                    .font(.interHeadline)
                                    .foregroundColor(Color.adaptiveText)
                                Text(card.description)
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveMuted)
                            }
                            
                            Spacer()
                        }
                        .cardStyle()
                        .cardEnterAnimation()
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                
                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .font(.interBody.bold())
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    OnboardingValueView(onContinue: {})
        .environment(\.colorScheme, .light)
}

