import SwiftUI

struct InsightPreviewView: View {
    let diagnoses: [String]
    let sensitivities: [String]
    var onContinue: () -> Void
    
    private var formattedDiagnoses: String {
        diagnoses.isEmpty ? "weather-sensitive conditions" : diagnoses.joined(separator: ", ")
    }
    
    private let previewSummary = "A gentle start gives way to a midweek wobble before easing toward the weekend—plan with soft buffers."
    
    private var previewDays: [WeeklyInsightDay] {
        [
            WeeklyInsightDay(label: "Sat", detail: "low flare risk"),
            WeeklyInsightDay(label: "Sun", detail: "humidity nudges up — may feel slightly more reactive"),
            WeeklyInsightDay(label: "Mon", detail: "quick shift arrives — may stir gentle tension"),
            WeeklyInsightDay(label: "Tue", detail: "low flare risk"),
            WeeklyInsightDay(label: "Wed", detail: "cool breeze holds — may keep nerves steadier"),
            WeeklyInsightDay(label: "Thu", detail: "winds wobble briefly — may feel lightly reactive"),
            WeeklyInsightDay(label: "Fri", detail: "low flare risk")
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your personalized insight preview")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                        .lineSpacing(4)
                    
                    Text("Here’s what daily and weekly guidance will look like once your data flows into the live experience.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .lineSpacing(4)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                
                VStack(spacing: 16) {
                    DailyInsightCardView(
                        title: "Daily AI Insight",
                        subtitle: "Today's Health Analysis",
                        icon: "lightbulb.fill",
                        message: """
Steady conditions settle in through the day.

Why: Stable pressure can ease tension in sensitive joints.

Comfort tip: Keep your day flexible.

Move at a pace that feels kind to you.
""",
                        supportNote: nil,
                        personalAnecdote: nil,
                        behaviorPrompt: nil,
                        citations: ["Source: Mayo Clinic – Weather and Pain", "Source: Arthritis Foundation – Barometric Pressure"],
                        disclaimerText: "Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.",
                        isLoading: false,
                        isRefreshing: false,
                        showRefreshButton: false,
                        showFeedbackPrompt: false,
                        onRefresh: nil,
                        feedbackBinding: nil,
                        submitFeedback: nil
                    )
                    .padding(.horizontal, 16)
                    
                    WeeklyForecastInsightCardView(
                        summary: previewSummary,
                        days: previewDays,
                        sources: ["Source: NIH Weather Sensitivity Brief"]
                    )
                }
                
                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .font(.interBody.bold())
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    InsightPreviewView(
        diagnoses: ["Migraines"],
        sensitivities: ["Pressure shifts"],
        onContinue: {}
    )
}

