import SwiftUI
import CoreData

struct OnboardingFlowView: View {
    enum Step: Hashable {
        case valueStack
        case diagnoses
        case sensitivities
        case preview
        case paywall
        case account
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var path: [Step] = []
    @State private var selectedDiagnoses: Set<String> = []
    @State private var selectedSensitivities: Set<String> = []
    
    var body: some View {
        NavigationStack(path: $path) {
            OnboardingHeroView {
                navigate(to: .valueStack)
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .valueStack:
                    OnboardingValueView {
                        navigate(to: .diagnoses)
                    }
                    .navigationBarBackButtonHidden(true)
                case .diagnoses:
                    DiagnosisSelectionView(
                        selectedDiagnoses: $selectedDiagnoses,
                        onContinue: {
                            navigate(to: .sensitivities)
                        },
                        onSkip: {
                            selectedDiagnoses.removeAll()
                            navigate(to: .sensitivities)
                        }
                    )
                case .sensitivities:
                    SensitivitySelectionView(
                        selectedSensitivities: $selectedSensitivities,
                        onContinue: {
                            navigate(to: .preview)
                        },
                        onSkip: {
                            selectedSensitivities.removeAll()
                            navigate(to: .preview)
                        }
                    )
                case .preview:
                    InsightPreviewView(
                        diagnoses: Array(selectedDiagnoses),
                        sensitivities: Array(selectedSensitivities),
                        onContinue: {
                            navigate(to: .paywall)
                        }
                    )
                case .paywall:
                    PaywallPlaceholderView(
                        onStartFreeWeek: {
                            navigate(to: .account)
                        }
                    )
                    .environmentObject(subscriptionManager)
                case .account:
                    AccountCreationView { name in
                        saveUserProfile(name: name)
                        UserDefaults.standard.set(Array(selectedSensitivities), forKey: "weatherSensitivities")
                        dismiss()
                    }
                    .environmentObject(authManager)
                }
            }
            .navigationBarHidden(true)
            .background(Color.adaptiveBackground.ignoresSafeArea())
        }
    }
    
    private func navigate(to step: Step) {
        path.append(step)
    }
    
    private func saveUserProfile(name: String) {
        let fetchRequest: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        let profile: UserProfile
        if let existing = try? viewContext.fetch(fetchRequest).first {
            profile = existing
        } else {
            profile = UserProfile(context: viewContext)
            profile.createdAt = Date()
        }
        
        profile.name = name.isEmpty ? "User" : name
        profile.updatedAt = Date()
        let diagnosesArray = Array(selectedDiagnoses).sorted()
        profile.setValue(diagnosesArray, forKey: "diagnoses")
        
        do {
            try viewContext.save()
            print("✅ Saved onboarding profile: \(diagnosesArray)")
        } catch {
            print("❌ Failed to save onboarding profile: \(error)")
        }
        
        persistSensitivities()
    }
    
    private func persistSensitivities() {
        let array = Array(selectedSensitivities).sorted()
        UserDefaults.standard.set(array, forKey: "weatherSensitivities")
        if let data = try? JSONEncoder().encode(array),
           let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: "weatherSensitivitiesJSON")
        } else {
            UserDefaults.standard.removeObject(forKey: "weatherSensitivitiesJSON")
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AuthManager())
        .environmentObject(SubscriptionManager.shared)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

