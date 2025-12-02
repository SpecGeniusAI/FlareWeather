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
                // Mark onboarding as in progress when starting
                authManager.isOnboardingInProgress = true
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
                            navigate(to: .account)
                        }
                    )
                case .account:
                    AccountCreationView { name in
                        print("📝 OnboardingFlowView: Account created, navigating to paywall...")
                        saveUserProfile(name: name)
                        UserDefaults.standard.set(Array(selectedSensitivities), forKey: "weatherSensitivities")
                        // Ensure onboarding flag is set to prevent ContentView from switching
                        authManager.isOnboardingInProgress = true
                        // Navigate to paywall immediately - must happen synchronously
                        print("📝 OnboardingFlowView: Current path before navigation: \(path)")
                        navigate(to: .paywall)
                        print("📝 OnboardingFlowView: Path after navigation: \(path)")
                    }
                    .environmentObject(authManager)
                    .onAppear {
                        // Ensure onboarding flag is set when account view appears
                        authManager.isOnboardingInProgress = true
                    }
                case .paywall:
                    PaywallPlaceholderView(
                        onStartFreeWeek: {
                            // Mark onboarding as complete after purchase
                            authManager.isOnboardingInProgress = false
                            dismiss()
                        }
                    )
                    .environmentObject(subscriptionManager)
                }
            }
            .navigationBarHidden(true)
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .onDisappear {
                // Reset onboarding flag if flow is dismissed early
                authManager.isOnboardingInProgress = false
            }
        }
    }
    
    private func navigate(to step: Step) {
        print("🧭 OnboardingFlowView: Navigating to step: \(step)")
        path.append(step)
        print("🧭 OnboardingFlowView: Path is now: \(path)")
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

