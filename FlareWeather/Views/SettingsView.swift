import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: false)],
        animation: .default)
    private var userProfiles: FetchedResults<UserProfile>
    
    @State private var showingOnboarding = false
    @State private var showingLocationSettings = false
    
    var currentUser: UserProfile? {
        userProfiles.first
    }
    
    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section("Profile") {
                    if let user = currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(user.name ?? "Unknown User")
                                    .font(.headline)
                                Text("Age: \(user.age)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Edit") {
                                // TODO: Edit profile
                            }
                        }
                    } else {
                        Button("Complete Profile Setup") {
                            showingOnboarding = true
                        }
                    }
                }
                
                // Location Settings
                Section("Location") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("Current Location")
                        Spacer()
                        Text("San Francisco, CA")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Update Location") {
                        showingLocationSettings = true
                    }
                }
                
                // Weather Settings
                Section("Weather") {
                    HStack {
                        Image(systemName: "cloud.sun.fill")
                            .foregroundColor(.orange)
                        Text("Weather Updates")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.red)
                        Text("Weather Alerts")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                }
                
                // Data & Privacy
                Section("Data & Privacy") {
                    Button("Export Data") {
                        // TODO: Export user data
                    }
                    
                    Button("Clear Cache") {
                        // TODO: Clear weather cache
                    }
                    
                    Button("Delete All Data", role: .destructive) {
                        // TODO: Delete all data with confirmation
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        // TODO: Show privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // TODO: Show terms of service
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .sheet(isPresented: $showingLocationSettings) {
                LocationSettingsView()
            }
        }
    }
}

struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var location = "San Francisco, CA"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Location") {
                    TextField("Enter your location", text: $location)
                }
                
                Section("Note") {
                    Text("FlareWeather uses your location to provide accurate weather data and correlate it with your symptoms.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Location Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save location
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
