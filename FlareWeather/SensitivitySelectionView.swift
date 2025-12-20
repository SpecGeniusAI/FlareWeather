import SwiftUI

struct SensitivitySelectionView: View {
    @Binding var selectedSensitivities: Set<String>
    var onBack: () -> Void
    var onContinue: () -> Void
    var onSkip: () -> Void
    
    private let factors = [
        "Pressure shifts",
        "Humidity swings",
        "Storm fronts",
        "Temperature changes"
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
                    Text("Any known weather sensitivities?")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                        .lineSpacing(4)
                    
                    Text("This optional step helps us highlight the weather triggers you already keep an eye on. You can update it anytime in Settings.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                VStack(spacing: 12) {
                    ForEach(factors, id: \.self) { factor in
                        SelectionRow(
                            title: factor,
                            isSelected: selectedSensitivities.contains(factor)
                        ) {
                            toggle(factor)
                        }
                        .cardStyle()
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
                    
                    Button(action: onSkip) {
                        Text("Skip")
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
    
    private func toggle(_ factor: String) {
        if selectedSensitivities.contains(factor) {
            selectedSensitivities.remove(factor)
        } else {
            selectedSensitivities.insert(factor)
        }
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
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SensitivitySelectionView(
        selectedSensitivities: .constant(["Pressure shifts"]),
        onBack: {},
        onContinue: {},
        onSkip: {}
    )
}

