import SwiftUI
import CoreData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var name = ""
    @State private var age = 25
    @State private var location = "San Francisco, CA"
    @State private var currentStep = 0
    
    let totalSteps = 3
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStepView()
                        .tag(0)
                    
                    ProfileStepView(name: $name, age: $age, location: $location)
                        .tag(1)
                    
                    PermissionsStepView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if currentStep < totalSteps - 1 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            createUserProfile()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func createUserProfile() {
        let newUser = UserProfile(context: viewContext)
        newUser.name = name.isEmpty ? "User" : name
        newUser.age = Int32(age)
        newUser.location = location
        newUser.createdAt = Date()
        newUser.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error creating user profile: \(error)")
        }
    }
}

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Welcome to FlareWeather")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track your symptoms and discover how weather patterns affect your health.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "cloud.sun.fill", title: "Weather Tracking", description: "Real-time weather data")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Trend Analysis", description: "Identify patterns over time")
                FeatureRow(icon: "brain.head.profile", title: "AI Insights", description: "Personalized recommendations")
            }
            .padding(.top)
        }
        .padding()
    }
}

struct ProfileStepView: View {
    @Binding var name: String
    @Binding var age: Int
    @Binding var location: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Tell us about yourself")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                TextField("Your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                VStack(alignment: .leading) {
                    Text("Age: \(age)")
                    Slider(value: Binding(
                        get: { Double(age) },
                        set: { age = Int($0) }
                    ), in: 18...100, step: 1)
                }
                
                TextField("Location", text: $location)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding()
    }
}

struct PermissionsStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Enable Permissions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("FlareWeather needs access to your location to provide accurate weather data and correlate it with your symptoms.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                PermissionRow(icon: "location.fill", title: "Location Access", description: "For weather data")
                PermissionRow(icon: "bell.fill", title: "Notifications", description: "Weather alerts and reminders")
                PermissionRow(icon: "heart.fill", title: "Health Data", description: "Optional: Sync with Health app")
            }
            .padding(.top)
        }
        .padding()
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
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
