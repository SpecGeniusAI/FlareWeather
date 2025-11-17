import SwiftUI

struct DiagnosisSelectionView: View {
    @Binding var selectedDiagnoses: Set<String>
    var onContinue: () -> Void
    var onSkip: () -> Void
    
    @State private var customDiagnosis = ""
    @State private var currentCustomValue = ""
    
    private let diagnoses = [
        "Fibromyalgia",
        "Migraines",
        "Arthritis",
        "Chronic Fatigue",
        "POTS",
        "Other"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Which conditions should we consider?")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("Choose the conditions that best describe you. This helps tailor insights to sensitivities that commonly pair with each diagnosis.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                VStack(spacing: 8) {
                    ForEach(diagnoses, id: \.self) { diagnosis in
                        VStack(alignment: .leading, spacing: 10) {
                            SelectionRow(
                                title: diagnosis,
                                isSelected: selectedDiagnoses.contains(diagnosis) || (diagnosis == "Other" && !customDiagnosis.isEmpty)
                            ) {
                                toggle(diagnosis)
                            }
                            
                            if diagnosis == "Other", selectedDiagnoses.contains("Other") {
                                TextField("Tell us more…", text: Binding(
                                    get: { customDiagnosis },
                                    set: { newValue in updateCustomDiagnosis(newValue) }
                                ))
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                                .tint(Color.adaptiveText)
                                .padding(12)
                                .background(Color.adaptiveBackground)
                                .cornerRadius(12)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .modifier(CompactCardStyle())
                        .padding(.horizontal, 16)
                    }
                }
                
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .font(.interBody.bold())
                            Spacer()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedDiagnoses.isEmpty)
                    .opacity(selectedDiagnoses.isEmpty ? 0.5 : 1)
                    
                    Button(action: onSkip) {
                        Text("Skip for now")
                            .font(.interBody)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggle(_ diagnosis: String) {
        if diagnosis == "Other" {
            if selectedDiagnoses.contains("Other") {
                selectedDiagnoses.remove("Other")
                if !customDiagnosis.isEmpty {
                    selectedDiagnoses.remove(customDiagnosis)
                }
                customDiagnosis = ""
                currentCustomValue = ""
            } else {
                selectedDiagnoses.insert("Other")
            }
        } else {
            if selectedDiagnoses.contains(diagnosis) {
                selectedDiagnoses.remove(diagnosis)
            } else {
                selectedDiagnoses.insert(diagnosis)
            }
        }
    }
    
    private func updateCustomDiagnosis(_ newValue: String) {
        // Remove previous custom entry
        if !currentCustomValue.isEmpty {
            selectedDiagnoses.remove(currentCustomValue)
        }
        
        customDiagnosis = newValue
        currentCustomValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !currentCustomValue.isEmpty {
            selectedDiagnoses.insert(currentCustomValue)
        }
    }
}

struct CompactCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 12) // Reduced from 20
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.adaptiveCardBackground)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 18, x: 0, y: 14)
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.03 : 0.25), Color.black.opacity(0.04)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                        .blendMode(.overlay)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.18),
                                    Color.white.opacity(colorScheme == .dark ? 0.01 : 0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 0.6)
                        .padding(.leading, 0.6)
                        .blendMode(.plusLighter)
                }
            )
    }
}

private struct SelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.adaptiveText : Color.adaptiveMuted, lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.adaptiveText)
                    }
                }
                
                Text(title)
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DiagnosisSelectionView(selectedDiagnoses: .constant(["Fibromyalgia"]), onContinue: {}, onSkip: {})
}

