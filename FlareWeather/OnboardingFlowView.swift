import SwiftUI
import CoreData
import UserNotifications

struct OnboardingFlowView: View {
    enum Step: Hashable {
        case valueStack
        case diagnoses
        case sensitivities
        case preview
        case paywall
        case account
        case notifications
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var notificationManager = NotificationManager()
    
    @State private var path: [Step] = []
    @State private var selectedDiagnoses: Set<String> = []
    @State private var selectedSensitivities: Set<String> = []
    
    var body: some View {
        NavigationStack(path: $path) {
            OnboardingHeroView(
                onBack: {
                    dismiss()
                },
                onContinue: {
                    // Mark onboarding as in progress when starting
                    authManager.isOnboardingInProgress = true
                    navigate(to: .valueStack)
                }
            )
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .valueStack:
                    OnboardingValueView(
                        onBack: {
                            dismiss()
                        },
                        onContinue: {
                            navigate(to: .diagnoses)
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                case .diagnoses:
                    DiagnosisSelectionView(
                        selectedDiagnoses: $selectedDiagnoses,
                        onBack: {
                            path.removeLast()
                        },
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
                        onBack: {
                            path.removeLast()
                        },
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
                        onBack: {
                            path.removeLast()
                        },
                        onContinue: {
                            navigate(to: .account)
                        }
                    )
                case .account:
                    AccountCreationView(
                        onBack: {
                            path.removeLast()
                        },
                        onSignupSuccess: { name in
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
                    )
                    .environmentObject(authManager)
                    .onAppear {
                        // Ensure onboarding flag is set when account view appears
                        authManager.isOnboardingInProgress = true
                    }
                case .paywall:
                    PaywallPlaceholderView(
                        onStartFreeWeek: {
                            // Navigate to notifications step after purchase
                            navigate(to: .notifications)
                        }
                    )
                    .environmentObject(subscriptionManager)
                case .notifications:
                    NotificationPermissionView(
                        notificationManager: notificationManager,
                        onContinue: {
                            // Mark onboarding as complete
                            authManager.isOnboardingInProgress = false
                            dismiss()
                        },
                        onSkip: {
                            // Mark onboarding as complete even if skipped
                            authManager.isOnboardingInProgress = false
                            dismiss()
                        }
                    )
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

// MARK: - Notification Permission View
struct NotificationPermissionView: View {
    @ObservedObject var notificationManager: NotificationManager
    var onContinue: () -> Void
    var onSkip: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header area
            VStack(spacing: 16) {
                Spacer()
                    .frame(height: 40)
                
                // Bell icon
                ZStack {
                    Circle()
                        .fill(Color.adaptiveAccent.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color.adaptiveAccent)
                }
                
                Text("Stay Ahead of Flares")
                    .font(.interTitle)
                    .foregroundColor(Color.adaptiveText)
                    .multilineTextAlignment(.center)
                
                Text("Get a daily forecast notification each morning so you can plan your day around how you'll feel.")
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Benefits list
            VStack(alignment: .leading, spacing: 16) {
                NotificationBenefitRow(
                    icon: "sun.max.fill",
                    title: "Morning Forecast",
                    description: "Know your flare risk before you start your day"
                )
                
                NotificationBenefitRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "High Risk Alerts",
                    description: "Get warned when major pressure shifts are coming"
                )
                
                NotificationBenefitRow(
                    icon: "heart.fill",
                    title: "Personalized Tips",
                    description: "Comfort suggestions based on your conditions"
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            
            Spacer()
            
            // Bottom buttons
            VStack(spacing: 12) {
                if notificationManager.authorizationStatus == .notDetermined {
                    Button {
                        Task {
                            print("📱 Onboarding: Requesting notification permission...")
                            await notificationManager.requestAuthorization()
                            // The requestAuthorization already handles token registration and sending
                            // But we'll also try sending again here as a backup
                            // Wait longer to ensure token is received from iOS
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                            AppDelegate.sendPushTokenIfNeeded()
                            // Try one more time after another delay
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 more seconds
                            AppDelegate.sendPushTokenIfNeeded()
                            print("📱 Onboarding: Notification permission flow complete")
                            onContinue()
                        }
                    } label: {
                        Text("Enable Notifications")
                            .font(.interBody.weight(.semibold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#2d3240") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.adaptiveAccent)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        onSkip()
                    } label: {
                        Text("Maybe Later")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                    }
                    .padding(.top, 4)
                } else if notificationManager.authorizationStatus == .authorized {
                    // Already enabled
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        
                        Text("Notifications Enabled!")
                            .font(.interBody.weight(.medium))
                            .foregroundColor(Color.adaptiveText)
                    }
                    .padding(.bottom, 8)
                    
                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.interBody.weight(.semibold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#2d3240") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.adaptiveAccent)
                            .cornerRadius(12)
                    }
                } else {
                    // Denied - show option to open settings
                    Text("Notifications are disabled. You can enable them anytime in Settings.")
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        notificationManager.openSystemSettings()
                    } label: {
                        Text("Open Settings")
                            .font(.interBody.weight(.semibold))
                            .foregroundColor(Color.adaptiveAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.adaptiveAccent.opacity(0.15))
                            .cornerRadius(12)
                    }
                    
                    Button {
                        onSkip()
                    } label: {
                        Text("Continue Without Notifications")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            notificationManager.refreshAuthorizationStatus()
        }
    }
}

struct NotificationBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.adaptiveAccent)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.interBody.weight(.semibold))
                    .foregroundColor(Color.adaptiveText)
                
                Text(description)
                    .font(.interCaption)
                    .foregroundColor(Color.adaptiveMuted)
            }
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AuthManager())
        .environmentObject(SubscriptionManager.shared)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

