import SwiftUI
import CoreData
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    init() {
        refreshAuthorizationStatus()
    }
    
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                Task { @MainActor in
                    self.refreshAuthorizationStatus()
                }
                continuation.resume()
            }
        }
    }
    
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    var statusDescription: String {
        switch authorizationStatus {
        case .authorized, .provisional:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        case .ephemeral:
            return "Limited"
        @unknown default:
            return "Unknown"
        }
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var name = ""
    @State private var age = 25
    @State private var location = "San Francisco, CA"
    @State private var selectedDiagnoses: Set<String> = []
    @State private var currentStep = 0
    @State private var stepTransition: AnyTransition = .identity
    @State private var isAnimatingBackground = false
    
    @StateObject private var notificationManager = NotificationManager()
    
    @Namespace private var stepIndicatorNamespace
    
    let totalSteps = 3
    
    let commonDiagnoses = [
        "Arthritis",
        "Fibromyalgia",
        "Migraine",
        "Chronic Pain",
        "Asthma",
        "COPD",
        "Allergies",
        "Multiple Sclerosis",
        "Lupus",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground(isAnimating: $isAnimatingBackground)
                    .ignoresSafeArea()
                VStack(spacing: 30) {
                    stepIndicator
                        .padding(.top, 12)
                    
                    ZStack {
                        switch currentStep {
                        case 0:
                            WelcomeStepView()
                                .transition(stepTransition)
                                .id(0)
                        case 1:
                            ProfileStepView(name: $name, age: $age, location: $location, selectedDiagnoses: $selectedDiagnoses, commonDiagnoses: commonDiagnoses)
                                .transition(stepTransition)
                                .id(1)
                        default:
                            PermissionsStepView(notificationManager: notificationManager)
                                .transition(stepTransition)
                                .id(2)
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
                    
                    navigationButtons
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .padding(.top, 24)
            }
            .navigationBarHidden(true)
            .tint(.primary)
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    isAnimatingBackground.toggle()
                }
            }
        }
        .tint(.primary)
    }
    
    private var stepIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Color.adaptiveCardBackground : Color.adaptiveMuted.opacity(0.2))
                    .frame(width: index == currentStep ? 42 : 14, height: 8)
                    .matchedGeometryEffect(id: "stepIndicator", in: stepIndicatorNamespace, isSource: index == currentStep)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentStep)
            }
        }
        .padding(.horizontal)
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    changeStep(to: currentStep - 1, movingForward: false)
                }
                .foregroundColor(Color.adaptiveText)
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                Button("Next") {
                    changeStep(to: currentStep + 1, movingForward: true)
                }
                .buttonStyle(PrimaryButtonStyle())
                .scaleEffect(1.05)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentStep)
            } else {
                Button("Get Started") {
                    createUserProfile()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .scaleEffect(1.05)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentStep)
            }
        }
    }
    
    private func changeStep(to newStep: Int, movingForward: Bool) {
        let insertionEdge: Edge = movingForward ? .trailing : .leading
        let removalEdge: Edge = movingForward ? .leading : .trailing
        stepTransition = .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            currentStep = newStep
        }
    }
    
    private func createUserProfile() {
        let newUser = UserProfile(context: viewContext)
        newUser.name = name.isEmpty ? "User" : name
        newUser.age = Int32(age)
        newUser.location = location
        // Store diagnoses as array
        let diagnosesArray = Array(selectedDiagnoses).filter { $0 != "Other" && !$0.isEmpty }
        newUser.setValue(diagnosesArray, forKey: "diagnoses")
        newUser.createdAt = Date()
        newUser.updatedAt = Date()
        
        do {
            try viewContext.save()
            print("✅ Created user profile with diagnoses: \(diagnosesArray)")
        } catch {
            print("❌ Error creating user profile: \(error)")
        }
    }
}

struct AnimatedGradientBackground: View {
    @Binding var isAnimating: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gradientColors: [Color] = colorScheme == .dark 
                ? [Color(hex: "#1A1A1A"), Color(hex: "#2A2A2A"), Color(hex: "#1E1E1E")]
                : [Color(hex: "#E7D6CA"), Color(hex: "#F1F1EF"), Color(hex: "#DEE7F5")]
            
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: isAnimating ? .topLeading : .bottomTrailing,
                endPoint: isAnimating ? .bottomTrailing : .topLeading
            )
            .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: isAnimating)
            .overlay(
                Circle()
                    .fill((colorScheme == .dark ? Color.white : Color.white).opacity(colorScheme == .dark ? 0.05 : 0.12))
                    .frame(width: size.width * 0.9)
                    .offset(x: isAnimating ? size.width * 0.15 : -size.width * 0.25, y: isAnimating ? -size.height * 0.2 : size.height * 0.25)
                    .blur(radius: 45)
            )
            .clipShape(Rectangle())
        }
    }
}

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .shadow(color: Color.adaptiveText.opacity(0.08), radius: 8, x: 0, y: 6)
                .padding(.top, 8)
            
            Text("Welcome to FlareWeather")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.adaptiveText)
                .transition(.opacity.combined(with: .scale))
            
            Text("Discover how weather patterns affect your health with AI-powered insights.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.adaptiveMuted)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "cloud.sun.fill", title: "Weather Tracking", description: "Real-time weather data")
                FeatureRow(icon: "brain.head.profile", title: "AI Insights", description: "Personalized health forecasts")
                FeatureRow(icon: "heart.text.square.fill", title: "Health Focused", description: "Based on your conditions")
            }
            .padding(.top)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .padding()
    }
}

struct ProfileStepView: View {
    @Binding var name: String
    @Binding var age: Int
    @Binding var location: String
    @Binding var selectedDiagnoses: Set<String>
    let commonDiagnoses: [String]
    
    @State private var otherDiagnosis = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Tell us about yourself")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText)
                
                VStack(spacing: 16) {
                    TextField("Your name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(Color.adaptiveText)
                        .tint(Color.adaptiveText)
                    
                    VStack(alignment: .leading) {
                        Text("Age: \(age)")
                            .foregroundColor(Color.adaptiveText)
                        Slider(value: Binding(
                            get: { Double(age) },
                            set: { age = Int($0) }
                        ), in: 18...100, step: 1)
                        .tint(Color.adaptiveCardBackground)
                    }
                    
                    TextField("Location", text: $location)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(Color.adaptiveText)
                        .tint(Color.adaptiveText)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Health Conditions (Optional)")
                            .font(.headline)
                            .foregroundColor(Color.adaptiveText)
                        
                        Text("Select all that apply to receive personalized insights")
                            .font(.caption)
                            .foregroundColor(Color.adaptiveMuted)
                        
                        // Multiple selection checkboxes
                        ForEach(commonDiagnoses.filter { $0 != "Other" }, id: \.self) { diagnosis in
                            Button(action: {
                                if selectedDiagnoses.contains(diagnosis) {
                                    selectedDiagnoses.remove(diagnosis)
                                } else {
                                    selectedDiagnoses.insert(diagnosis)
                                }
                            }) {
                                HStack {
                                    ZStack {
                                        // Background for better visibility
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedDiagnoses.contains(diagnosis) ? Color.adaptiveCardBackground : Color.clear)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(selectedDiagnoses.contains(diagnosis) ? Color.adaptiveCardBackground : Color.adaptiveMuted, lineWidth: 2)
                                            )
                                        if selectedDiagnoses.contains(diagnosis) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(Color.adaptiveText)
                                        }
                                    }
                                    Text(diagnosis)
                                        .foregroundColor(Color.adaptiveText)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Other option
                        if commonDiagnoses.contains("Other") {
                            Button(action: {
                                if selectedDiagnoses.contains("Other") {
                                    selectedDiagnoses.remove("Other")
                                    otherDiagnosis = ""
                                } else {
                                    selectedDiagnoses.insert("Other")
                                }
                            }) {
                                HStack {
                                    ZStack {
                                        // Background for better visibility
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedDiagnoses.contains("Other") ? Color.adaptiveCardBackground : Color.clear)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(selectedDiagnoses.contains("Other") ? Color.adaptiveCardBackground : Color.adaptiveMuted, lineWidth: 2)
                                            )
                                        if selectedDiagnoses.contains("Other") {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(Color.adaptiveText)
                                        }
                                    }
                                    Text("Other")
                                        .foregroundColor(Color.adaptiveText)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            
                            if selectedDiagnoses.contains("Other") {
                                TextField("Enter your condition", text: $otherDiagnosis)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .foregroundColor(Color.adaptiveText)
                                    .tint(Color.adaptiveText)
                                    .onChange(of: otherDiagnosis) { _, newValue in
                                        if !newValue.isEmpty {
                                            selectedDiagnoses.remove("Other")
                                            selectedDiagnoses.insert(newValue)
                                        }
                                    }
                            }
                        }
                        
                        if !selectedDiagnoses.isEmpty {
                            Text("This helps us provide more personalized insights")
                                .font(.caption)
                                .foregroundColor(Color.adaptiveText)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct PermissionsStepView: View {
    @ObservedObject var notificationManager: NotificationManager
    var body: some View {
        VStack(spacing: 20) {
            Text("Enable Permissions")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText)
            
            Text("FlareWeather needs access to your location to provide accurate weather data and personalized health insights.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.adaptiveMuted)
            
            VStack(alignment: .leading, spacing: 16) {
                PermissionRow(icon: "location.fill", title: "Location Access", description: "For weather data")
                PermissionRow(icon: "bell.fill", title: "Notifications", description: "Weather alerts and reminders")
                PermissionRow(icon: "heart.fill", title: "Health Data", description: "Optional: Sync with Health app")
            }
            .padding(.top)
            
            VStack(spacing: 12) {
                Text("We'll only send notifications when weather changes might impact your symptoms. You can skip for now and enable them later in Settings.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.adaptiveMuted)
                    .fixedSize(horizontal: false, vertical: true)
                
                if notificationManager.authorizationStatus == .notDetermined {
                    Button {
                        Task { await notificationManager.requestAuthorization() }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Turn On Notifications")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if notificationManager.authorizationStatus == .denied {
                    Button("Open Notification Settings") {
                        notificationManager.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    Text("Notifications are currently disabled. You can re-enable them in Settings later.")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveMuted)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Notifications are enabled—you're all set for gentle pressure alerts.")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveMuted)
                }
            }
        }
        .padding()
        .onAppear {
            notificationManager.refreshAuthorizationStatus()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.adaptiveText)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.adaptiveText)
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.adaptiveMuted)
            }
            
            Spacer()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.adaptiveCardBackground)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.adaptiveText)
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.adaptiveMuted)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
