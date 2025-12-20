import SwiftUI

struct DiagnosisSelectionView: View {
    @Binding var selectedDiagnoses: Set<String>
    var onBack: () -> Void
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
        .navigationBarBackButtonHidden(true)
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
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        colorScheme == .dark
                            ? AnyShapeStyle(Color.adaptiveCardBackground)
                            : AnyShapeStyle(Color.white)
                    )
            )
            .shadow(
                color: colorScheme == .dark 
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.05),
                radius: colorScheme == .dark ? 8 : 4,
                x: 0,
                y: colorScheme == .dark ? 4 : 2
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
    DiagnosisSelectionView(selectedDiagnoses: .constant(["Fibromyalgia"]), onBack: {}, onContinue: {}, onSkip: {})
}

