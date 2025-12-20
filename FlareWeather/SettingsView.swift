import SwiftUI
import CoreData
import CoreLocation
import MapKit
import Combine
import Security
#if canImport(RevenueCat)
import RevenueCat
import RevenueCatUI
#endif

// Location search manager for autocomplete
class LocationSearchManager: NSObject, ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var searchError: String? = nil
    
    private let searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        
        // Use a broader default region that covers more of the world
        // This helps prevent region-related errors
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -100.0), // Center of North America
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360) // Cover the whole world
        )
        
        // Update search results as user types
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.updateSearchQuery(query)
            }
            .store(in: &cancellables)
    }
    
    /// Update the search completer region based on user's current location
    func updateRegion(with location: CLLocation?) {
        if let location = location {
            searchCompleter.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
            )
        }
    }
    
    private func updateSearchQuery(_ query: String) {
        // Clear previous errors
        searchError = nil
        
        if query.isEmpty {
            searchResults = []
            isSearching = false
        } else {
            // Reset and retry search
            searchCompleter.queryFragment = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.searchCompleter.queryFragment = query
                self?.isSearching = true
            }
        }
    }
    
    func geocode(completion: MKLocalSearchCompletion, completionHandler: @escaping (CLLocation?, String?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completionHandler(nil, error.localizedDescription)
                    return
                }
                
                guard let mapItem = response?.mapItems.first,
                      let location = mapItem.placemark.location else {
                    completionHandler(nil, "Location not found")
                    return
                }
                
                // Format the location name nicely
                let locationName = completion.title + (completion.subtitle.isEmpty ? "" : ", \(completion.subtitle)")
                completionHandler(location, locationName)
            }
        }
    }
}

extension LocationSearchManager: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        isSearching = false
        searchError = nil // Clear error on success
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("❌ Search completer error: \(error.localizedDescription)")
        isSearching = false
        
        // Handle specific error codes
        if let mkError = error as NSError? {
            switch mkError.code {
            case 2: // MKErrorUnknown
                // Try resetting the region to a broader scope
                searchCompleter.region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 40.0, longitude: -100.0),
                    span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
                )
                // Retry the query if we have one
                if !searchText.isEmpty {
                    searchCompleter.queryFragment = searchText
                }
                searchError = "Search temporarily unavailable. Please try again."
            case 3: // MKErrorServerFailure
                searchError = "Search service unavailable. Check your connection."
            case 4: // MKErrorLoadingThrottled
                searchError = "Too many searches. Please wait a moment."
            default:
                searchError = "Search error. Please try again."
            }
        } else {
            searchError = "Search error. Please try again."
        }
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: false)],
        animation: .default)
    private var userProfiles: FetchedResults<UserProfile>
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var themeManager = ThemeManager()
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("weatherSensitivitiesJSON") private var weatherSensitivitiesJSON: String = ""
    @State private var showingOnboarding = false
    @State private var showingLocationSettings = false
    @State private var showingProfileEdit = false
    @State private var showDeleteAlert = false
    @State private var deleteErrorMessage: String?
    @State private var isDeletingAccount = false
    
    var currentUser: UserProfile? {
        userProfiles.first
    }
    
    private var storedSensitivities: [String] {
        if let data = weatherSensitivitiesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        return UserDefaults.standard.stringArray(forKey: "weatherSensitivities") ?? []
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Profile")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        .padding(.bottom, 16)
                        
                    if let user = currentUser {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                    .foregroundColor(Color.adaptiveText)
                            
                                VStack(alignment: .leading, spacing: 8) {
                                Text(user.name ?? "Unknown User")
                                        .font(.interHeadline)
                                        .foregroundColor(Color.adaptiveText)
                                    
                                    if let diagnosesArray = user.value(forKey: "diagnoses") as? NSArray,
                                       let diagnoses = diagnosesArray as? [String], !diagnoses.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(diagnoses, id: \.self) { diagnosis in
                                                HStack {
                                                    Image(systemName: "heart.text.square.fill")
                                                        .font(.interCaption)
                                                        .foregroundColor(Color.adaptiveMuted)
                                                    Text(diagnosis)
                                                        .font(.interCaption)
                                                        .foregroundColor(Color.adaptiveMuted)
                                                }
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                    
                                    let sensitivities = storedSensitivities
                                    if !sensitivities.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Weather Sensitivities")
                                                .font(.interBody.weight(.semibold))
                                                .foregroundColor(Color.adaptiveText)
                                            ForEach(sensitivities, id: \.self) { sensitivity in
                                                HStack {
                                                    Image(systemName: "waveform.path.ecg")
                                                        .font(.interCaption)
                                                        .foregroundColor(Color.adaptiveMuted)
                                                    Text(sensitivity)
                                                        .font(.interCaption)
                                                        .foregroundColor(Color.adaptiveMuted)
                                                }
                                            }
                                        }
                                        .padding(.top, 8)
                                    }
                            }
                            
                            Spacer()
                            }
                            
                            Button("Edit Profile") {
                                showingProfileEdit = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    } else {
                        Button("Complete Profile Setup") {
                            showingOnboarding = true
                        }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                    .cardStyle()
                    .padding(.horizontal)
                
                    // Your Plan (Subscription)
                    SubscriptionPlanSection()
                        .environmentObject(SubscriptionManager.shared)
                
                    // Appearance Settings
                    VStack(alignment: .leading, spacing: 16) {
                    HStack {
                            Image(systemName: "paintbrush.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Appearance")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                        Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Dark Mode")
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveText)
                                
                                Picker("Color Scheme", selection: $themeManager.colorSchemePreference) {
                                    ForEach(ColorSchemePreference.allCases, id: \.self) { preference in
                                        Text(preference.rawValue.capitalized).tag(preference)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            Divider()
                                .background(Color.adaptiveMuted.opacity(0.3))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Temperature Unit")
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveText)
                                
                                Picker("Temperature Unit", selection: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "useFahrenheit") ? 1 : 0 },
                                    set: { UserDefaults.standard.set($0 == 1, forKey: "useFahrenheit") }
                                )) {
                                    Text("Celsius").tag(0)
                                    Text("Fahrenheit").tag(1)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Notifications
                    VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "bell.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Notifications")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                        Spacer()
                            Text(notificationManager.statusDescription)
                                .font(.interCaption)
                                .foregroundColor(Color.adaptiveMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.adaptiveCardBackground.opacity(0.35))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pressure alerts give you a gentle heads up when quick weather swings could affect your symptoms.")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if notificationManager.authorizationStatus == .notDetermined {
                                Button {
                                    Task { await notificationManager.requestAuthorization() }
                                } label: {
                                    HStack {
                                        Image(systemName: "bell.badge")
                                        Text("Enable Notifications")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            } else if notificationManager.authorizationStatus == .denied {
                                Text("Notifications are currently turned off. You can enable them in Settings to receive pressure alerts.")
                                    .font(.interCaption)
                                    .foregroundColor(Color.adaptiveMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Button("Open Notification Settings") {
                                    notificationManager.openSystemSettings()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            } else {
                                Text("You're set to receive pressure alerts. You can update preferences anytime in Settings.")
                                    .font(.interCaption)
                                    .foregroundColor(Color.adaptiveMuted)
                                
                                Button("Manage in Settings") {
                                    notificationManager.openSystemSettings()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Location Card
                    VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Location")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        if locationManager.useDeviceLocation {
                            if let location = locationManager.location {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(Color.adaptiveMuted)
                                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Location")
                                            .font(.interBody)
                                            .foregroundColor(Color.adaptiveText)
                                        if let name = locationManager.deviceLocationName, !name.isEmpty {
                                            Text(name)
                                                .font(.interCaption)
                                                .foregroundColor(Color.adaptiveMuted)
                                        } else {
                                            Text("\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
                                                .font(.interCaption)
                                                .foregroundColor(Color.adaptiveMuted)
                                        }
                                    }
                        Spacer()
                                }
                            } else {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(Color.adaptiveText)
                                    Text("Getting location...")
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveMuted)
                                }
                            }
                            
                            if locationManager.authorizationStatus == .denied {
                        Text("Location access denied. Enable it in Settings.")
                                    .font(.interCaption)
                                    .foregroundColor(.red)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(Color.adaptiveMuted)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Selected Location")
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveText)
                                    if let name = locationManager.manualLocationName, !name.isEmpty {
                                        Text(name)
                                            .font(.interCaption)
                                            .foregroundColor(Color.adaptiveMuted)
                                    } else {
                                        Text("Choose a city in Location Settings")
                                            .font(.interCaption)
                                            .foregroundColor(Color.adaptiveMuted)
                                    }
                                }
                                Spacer()
                            }
                        }
                        
                        Button("Location Settings") {
                            showingLocationSettings = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    
                    // About Card
                    VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("About")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        HStack {
                        Text("Version")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                        Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveMuted)
                        }
                        
                        if let privacyURL = URL(string: "https://www.flareweather.app/privacy-policy") {
                            Link(destination: privacyURL) {
                                HStack {
                                    Text("Privacy Policy")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        
                        if let termsURL = URL(string: "https://www.flareweather.app/terms-of-service") {
                            Link(destination: termsURL) {
                                HStack {
                                    Text("Terms of Service")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    if let deleteErrorMessage = deleteErrorMessage {
                        Text(deleteErrorMessage)
                            .font(.interCaption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text(isDeletingAccount ? "Deleting..." : "Delete Account")
                        }
                        .font(.interBody.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .disabled(isDeletingAccount)
                    
                    Button(action: {
                        authManager.logout()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Log Out")
                        }
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .onAppear {
                notificationManager.refreshAuthorizationStatus()
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.adaptiveMuted)
                    }
                }
            }
            .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
            .tint(Color.adaptiveText)
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .sheet(isPresented: $showingLocationSettings) {
                LocationSettingsView(locationManager: locationManager)
            }
            .sheet(isPresented: $showingProfileEdit) {
                if let user = currentUser {
                    ProfileEditView(user: user)
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and remove your saved preferences. This action cannot be undone.")
            }
        }
    }
    
    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        deleteErrorMessage = nil
        isDeletingAccount = true
        do {
            try await authManager.deleteAccount()
            removeLocalProfile()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
        isDeletingAccount = false
    }
    
    private func removeLocalProfile() {
        if let profile = currentUser {
            viewContext.delete(profile)
            try? viewContext.save()
        }
        weatherSensitivitiesJSON = ""
        UserDefaults.standard.removeObject(forKey: "weatherSensitivities")
    }
}

struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager: LocationManager
    @StateObject private var searchManager = LocationSearchManager()
    @State private var useDeviceLocation = true
    @State private var manualLocation = ""
    @State private var tempManualLocation = ""
    @State private var isGeocoding = false
    @State private var geocodeError: String? = nil
    @State private var geocodedLocation: CLLocation? = nil
    @State private var selectedLocationName: String? = nil
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Location Source")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Use Device Location", isOn: $useDeviceLocation)
                                .tint(Color.adaptiveCardBackground)
                                .onChange(of: useDeviceLocation) { _, newValue in
                                    if newValue {
                                        // Clear manual location when switching to device
                                        tempManualLocation = ""
                                        geocodedLocation = nil
                                        geocodeError = nil
                                        selectedLocationName = nil
                                        isSearchFieldFocused = false
                                    }
                                }
                            
                            if useDeviceLocation {
                                if let location = locationManager.location {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(Color.adaptiveMuted)
                                        Text("Current Location")
                                            .font(.interBody)
                                            .foregroundColor(Color.adaptiveText)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            if let humanName = locationManager.deviceLocationName ?? locationManager.manualLocationName {
                                                Text(humanName)
                                                    .font(.interCaption)
                                                    .foregroundColor(Color.adaptiveMuted)
                                            } else {
                                                Text("\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
                                                    .font(.interCaption)
                                                    .foregroundColor(Color.adaptiveMuted)
                                            }
                                        }
                                    }
                                } else {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(Color.adaptiveText)
                                        Text("Getting location...")
                                            .font(.interBody)
                                            .foregroundColor(Color.adaptiveMuted)
                                    }
                                }
                                
                                if locationManager.authorizationStatus == .denied {
                                    Text("Location access denied. Enable it in Settings.")
                                        .font(.interCaption)
                                        .foregroundColor(.red)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ZStack(alignment: .leading) {
                                            if tempManualLocation.isEmpty {
                                                Text("Search for your city (e.g., Victoria, BC)")
                                                    .font(.interBody)
                                                    .foregroundColor(Color.adaptiveMuted)
                                                    .padding(.horizontal, 12)
                                            }
                                            TextField("", text: $tempManualLocation)
                                                .font(.interBody)
                                                .foregroundColor(Color.adaptiveText)
                                                .tint(Color.adaptiveText)
                                                .padding(12)
                                                .autocapitalization(.words)
                                                .disableAutocorrection(false)
                                                .focused($isSearchFieldFocused)
                                                .onChange(of: tempManualLocation) { _, newValue in
                                                    searchManager.searchText = newValue
                                                    // Clear selected location and errors when typing
                                                    if geocodedLocation != nil {
                                                        geocodedLocation = nil
                                                        selectedLocationName = nil
                                                        geocodeError = nil
                                                    }
                                                }
                                                .onAppear {
                                                    // Update search region based on user's location if available
                                                    if let location = locationManager.location {
                                                        searchManager.updateRegion(with: location)
                                                    }
                                                }
                                        }
                                        .background(Color.adaptiveBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isSearchFieldFocused ? Color.adaptiveCardBackground : Color.clear, lineWidth: 2)
                                        )
                                        
                                        // Display search error if present
                                        if let searchError = searchManager.searchError {
                                            Text(searchError)
                                                .font(.interCaption)
                                                .foregroundColor(.orange)
                                                .padding(.top, 4)
                                        }
                                        
                                        // Display loading indicator while searching
                                        if searchManager.isSearching {
                                            HStack(spacing: 8) {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .tint(Color.adaptiveMuted)
                                                Text("Searching...")
                                                    .font(.interCaption)
                                                    .foregroundColor(Color.adaptiveMuted)
                                            }
                                            .padding(.top, 4)
                                        }
                                        
                                        // Dropdown with search results
                                        if isSearchFieldFocused && !searchManager.searchResults.isEmpty {
                                            let displayedResults = Array(searchManager.searchResults.prefix(5).enumerated())
                                            ScrollView {
                                                VStack(alignment: .leading, spacing: 0) {
                                                    ForEach(displayedResults, id: \.offset) { index, result in
                                                        Button(action: {
                                                            selectLocation(result)
                                                        }) {
                                                            HStack {
                                                                VStack(alignment: .leading, spacing: 2) {
                                                                    Text(result.title)
                                                                        .font(.interBody)
                                                                        .foregroundColor(Color.adaptiveText)
                                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                                    if !result.subtitle.isEmpty {
                                                                        Text(result.subtitle)
                                                                            .font(.interCaption)
                                                                            .foregroundColor(Color.adaptiveMuted)
                                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                                    }
                                                                }
                                                                Spacer()
                                                                Image(systemName: "chevron.right")
                                                                    .font(.interCaption)
                                                                    .foregroundColor(Color.adaptiveMuted)
                                                            }
                                                            .padding(12)
                                                            .background(Color.adaptiveBackground)
                                                        }
                                                        .buttonStyle(.plain)
                                                        
                                                        if index < displayedResults.count - 1 {
                                                            Divider()
                                                                .padding(.leading, 12)
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxHeight: 200)
                                            .background(Color.adaptiveCardBackground)
                                            .cornerRadius(12)
                                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                            .padding(.top, 4)
                                        }
                                        
                                        if isGeocoding {
                                            HStack {
                                                ProgressView()
                                                    .tint(Color.adaptiveText)
                                                    .scaleEffect(0.8)
                                                Text("Finding location...")
                                                    .font(.interCaption)
                                                    .foregroundColor(Color.adaptiveMuted)
                                            }
                                            .padding(.top, 4)
                                        }
                                        
                                        // Show error only if not currently geocoding and no location found
                                        if let error = geocodeError, !isGeocoding, geocodedLocation == nil {
                                            HStack {
                                                Image(systemName: "exclamationmark.circle.fill")
                                                    .foregroundColor(.red)
                                                Text(error)
                                                    .font(.interCaption)
                                                    .foregroundColor(.red)
                                            }
                                            .padding(.top, 4)
                                            .transition(.opacity)
                                        }
                                        
                                        // Show success confirmation
                                        if geocodedLocation != nil, let locationName = selectedLocationName, !isGeocoding {
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                Text(locationName)
                                                    .font(.interCaption)
                                                    .foregroundColor(Color.adaptiveMuted)
                                            }
                                            .padding(.top, 4)
                                            .transition(.opacity.combined(with: .scale))
                                        }
                                    }
                                }
                            }
                            
                            Text("FlareWeather uses your location to provide accurate weather data and personalized health insights.")
                                .font(.interSmall)
                                .foregroundColor(Color.adaptiveMuted)
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                        .buttonStyle(SecondaryButtonStyle())
                
                    Button("Save") {
                            saveLocation()
                        dismiss()
                    }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!useDeviceLocation && geocodedLocation == nil)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Location Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
            .onAppear {
                useDeviceLocation = UserDefaults.standard.bool(forKey: "useDeviceLocation")
                manualLocation = UserDefaults.standard.string(forKey: "manualLocation") ?? ""
                tempManualLocation = manualLocation
                if useDeviceLocation && locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestLocation()
                } else if !useDeviceLocation && !manualLocation.isEmpty {
                    geocodeLocation()
                }
                // Update search region based on user's location if available
                if let location = locationManager.location {
                    searchManager.updateRegion(with: location)
                }
            }
            .onChange(of: locationManager.location) { _, newLocation in
                // Update search region when location becomes available
                if let location = newLocation {
                    searchManager.updateRegion(with: location)
                }
            }
        }
    }
    
    private func selectLocation(_ completion: MKLocalSearchCompletion) {
        let locationName = completion.title + (completion.subtitle.isEmpty ? "" : ", \(completion.subtitle)")
        tempManualLocation = locationName
        isSearchFieldFocused = false
        
        // Clear any previous errors
        geocodeError = nil
        geocodedLocation = nil
        selectedLocationName = nil
        
        isGeocoding = true
        
        // Use MKLocalSearch to get the actual location
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    let nsError = error as NSError
                    // Don't show errors for cancelled searches
                    if nsError.code != NSUserCancelledError {
                        let errorMsg = error.localizedDescription
                        // Check error type for better messages
                        if nsError.domain == NSURLErrorDomain {
                            switch nsError.code {
                            case NSURLErrorNotConnectedToInternet:
                                self.geocodeError = "No internet connection. Please check your network."
                            case NSURLErrorTimedOut:
                                self.geocodeError = "Request timed out. Please try again."
                            default:
                                self.geocodeError = "Could not find location: \(errorMsg)"
                            }
                        } else {
                            self.geocodeError = "Could not find location: \(errorMsg)"
                        }
                        print("❌ Geocoding error: \(errorMsg)")
                    }
                    return
                }
                
                guard let response = response, !response.mapItems.isEmpty else {
                    print("⚠️  MKLocalSearch returned empty response, trying fallback...")
                    self.geocodeLocationFallback(locationName)
                    return
                }
                
                guard let mapItem = response.mapItems.first,
                      let location = mapItem.placemark.location else {
                    print("⚠️  MKLocalSearch didn't return location, trying fallback...")
                    self.geocodeLocationFallback(locationName)
                    return
                }
                
                // Success!
                self.geocodedLocation = location
                self.selectedLocationName = locationName
                self.geocodeError = nil
                print("✅ Selected location: \(locationName) at \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        }
    }
    
    private func geocodeLocationFallback(_ locationName: String) {
        // Fallback to CLGeocoder if MKLocalSearch fails
        // Keep isGeocoding true since we're still trying
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(locationName) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    // Check if it's a rate limit or network error
                    let nsError = error as NSError
                    if nsError.domain == kCLErrorDomain {
                        switch nsError.code {
                        case CLError.geocodeFoundNoResult.rawValue, CLError.geocodeFoundPartialResult.rawValue:
                            self.geocodeError = "Could not find coordinates for this location. Please try a more specific search."
                        case CLError.network.rawValue:
                            self.geocodeError = "Network error. Please check your connection and try again."
                        default:
                            self.geocodeError = "Could not find location. Please try a different search term."
                        }
                    } else {
                        self.geocodeError = "Could not find location. Please try a different search term."
                    }
                    print("❌ Fallback geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    self.geocodeError = "Could not find coordinates for this location"
                    print("❌ No location found in fallback geocoding")
                    return
                }
                
                self.geocodedLocation = location
                self.selectedLocationName = locationName
                self.geocodeError = nil
                print("✅ Fallback geocoded: \(locationName) at \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        }
    }
    
    private func geocodeLocation() {
        guard !tempManualLocation.isEmpty else { return }
        
        isGeocoding = true
        geocodeError = nil
        geocodedLocation = nil
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(tempManualLocation) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let error = error {
                    self.geocodeError = "Could not find location: \(error.localizedDescription)"
                    print("❌ Geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    self.geocodeError = "Location not found. Try a different format (e.g., 'City, State' or 'City, Country')."
                    print("❌ No location found for: \(self.tempManualLocation)")
                    return
                }
                
                self.geocodedLocation = location
                self.selectedLocationName = self.tempManualLocation
                self.geocodeError = nil
                print("✅ Geocoded '\(self.tempManualLocation)' to: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        }
    }
    
    private func saveLocation() {
        UserDefaults.standard.set(useDeviceLocation, forKey: "useDeviceLocation")
        locationManager.useDeviceLocation = useDeviceLocation
        
        if useDeviceLocation {
            // Clear manual location when using device
            UserDefaults.standard.removeObject(forKey: "manualLocation")
            UserDefaults.standard.removeObject(forKey: "manualLocationLat")
            UserDefaults.standard.removeObject(forKey: "manualLocationLon")
            locationManager.manualLocationName = nil
        } else if let location = geocodedLocation {
            // Save manual location (use selectedLocationName if available, otherwise use tempManualLocation)
            let locationToSave = selectedLocationName ?? tempManualLocation
            locationManager.manualLocationName = locationToSave
            UserDefaults.standard.set(locationToSave, forKey: "manualLocation")
            // Store coordinates for easy access
            UserDefaults.standard.set(location.coordinate.latitude, forKey: "manualLocationLat")
            UserDefaults.standard.set(location.coordinate.longitude, forKey: "manualLocationLon")
            // Update LocationManager to use the new manual location
            // This will trigger onChange in HomeView
            DispatchQueue.main.async {
                self.locationManager.location = location
                // Also reload to ensure it's properly set
                self.locationManager.loadManualLocation()
                print("✅ Saved manual location: \(locationToSave) at \(location.coordinate.latitude), \(location.coordinate.longitude)")
                
                // Send location to backend if user is logged in
                Task {
                    await self.sendLocationToBackend(location: location, locationName: locationToSave)
                }
            }
        }
    }
    
    // Send location to backend
    private func sendLocationToBackend(location: CLLocation, locationName: String) async {
        guard let authToken = loadAuthToken() else {
            print("⏭️ No auth token - skipping location update to backend")
            return
        }
        
        guard let backendURL = Bundle.main.object(forInfoDictionaryKey: "BackendURL") as? String,
              let url = URL(string: "\(backendURL)/user/location") else {
            print("❌ Invalid backend URL for location update")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "location_name": locationName
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Location sent to backend: \(locationName)")
                } else {
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    print("⚠️ Failed to send location: HTTP \(httpResponse.statusCode) - \(responseBody)")
                }
            }
        } catch {
            print("❌ Error sending location to backend: \(error.localizedDescription)")
        }
    }
    
    // Load auth token from keychain
    private func loadAuthToken() -> String? {
        let tokenKey = "flareweather_access_token"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
}

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("weatherSensitivitiesJSON") private var weatherSensitivitiesJSON: String = ""
    var user: UserProfile
    
    @State private var name: String
    @State private var selectedDiagnoses: Set<String> = []
    @State private var selectedSensitivities: Set<String> = []
    @State private var otherDiagnosis = ""
    
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
    
    let sensitivityOptions = [
        "Pressure shifts",
        "Humidity swings",
        "Storm fronts",
        "Temperature changes"
    ]
    
    init(user: UserProfile) {
        self.user = user
        _name = State(initialValue: user.name ?? "")
        // Load existing diagnoses
        if let diagnosesArray = user.value(forKey: "diagnoses") as? NSArray,
           let diagnoses = diagnosesArray as? [String] {
            _selectedDiagnoses = State(initialValue: Set(diagnoses))
        }
        
        if let json = UserDefaults.standard.string(forKey: "weatherSensitivitiesJSON"),
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            _selectedSensitivities = State(initialValue: Set(decoded))
        } else if let legacy = UserDefaults.standard.stringArray(forKey: "weatherSensitivities") {
            _selectedSensitivities = State(initialValue: Set(legacy))
        } else {
            _selectedSensitivities = State(initialValue: [])
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Information Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Profile Information")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Name", text: $name)
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                                .tint(Color.adaptiveText)
                                .padding(12)
                                .background(Color.adaptiveBackground)
                                .cornerRadius(12)
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Health Diagnosis Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "heart.text.square.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Health Conditions")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select all that apply to receive personalized insights")
                                .font(.interCaption)
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
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveText)
                                    .tint(Color.adaptiveText)
                                    .padding(12)
                                    .background(Color.adaptiveBackground)
                                    .cornerRadius(12)
                                    .onChange(of: otherDiagnosis) { _, newValue in
                                        if !newValue.isEmpty {
                                            selectedDiagnoses.remove("Other")
                                            selectedDiagnoses.insert(newValue)
                                        }
                                    }
                            }
                            
                            if !selectedDiagnoses.isEmpty {
                                Text("This helps us provide more personalized insights")
                                    .font(.interCaption)
                                    .foregroundColor(Color.adaptiveMuted)
                                    .padding(.top, 4)
                            }
                            
                            Text("Your conditions help personalize AI insights and find relevant research.")
                                .font(.interSmall)
                                .foregroundColor(Color.adaptiveMuted)
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Weather Sensitivities Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Weather Sensitivities")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        Text("Select the weather triggers that usually get your attention. We’ll use them to highlight key moments in forecasts.")
                            .font(.interCaption)
                            .foregroundColor(Color.adaptiveMuted)
                            .lineSpacing(4)
                        
                        VStack(spacing: 12) {
                            ForEach(sensitivityOptions, id: \.self) { option in
                                Button(action: {
                                    if selectedSensitivities.contains(option) {
                                        selectedSensitivities.remove(option)
                                    } else {
                                        selectedSensitivities.insert(option)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedSensitivities.contains(option) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedSensitivities.contains(option) ? Color.adaptiveCardBackground : Color.adaptiveMuted)
                                        Text(option)
                                            .foregroundColor(Color.adaptiveText)
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Save Button
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Save") {
                            saveProfile()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.isEmpty)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.interBody)
                        }
                        .foregroundColor(Color.adaptiveText)
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        user.setValue(name, forKey: "name")
        // Store diagnoses as array
        let diagnosesArray = Array(selectedDiagnoses).filter { $0 != "Other" && !$0.isEmpty }
        user.setValue(diagnosesArray, forKey: "diagnoses")
        user.setValue(Date(), forKey: "updatedAt")
        
        do {
            try viewContext.save()
            print("✅ Updated user profile. Diagnoses: \(diagnosesArray)")
            saveSensitivities()
            dismiss()
        } catch {
            print("❌ Error saving profile: \(error)")
        }
    }
    
    private func saveSensitivities() {
        let array = Array(selectedSensitivities).sorted()
        UserDefaults.standard.set(array, forKey: "weatherSensitivities")
        if let data = try? JSONEncoder().encode(array),
           let json = String(data: data, encoding: .utf8) {
            weatherSensitivitiesJSON = json
        } else {
            weatherSensitivitiesJSON = ""
        }
    }
}

// MARK: - Subscription Plan Section
struct SubscriptionPlanSection: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingPaywall = false
    @State private var showManage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                Text("Your Plan")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
            }
            
            if subscriptionManager.isProUser {
                // Subscribed state
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Flare Pro")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text(subscriptionManager.currentPlan == .yearly ? "Yearly" : "Monthly")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveMuted)
                        }
                        
                        Spacer()
                        
                        Text("Active")
                            .font(.interCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    Divider()
                        .background(Color.adaptiveMuted.opacity(0.3))
                    
                    // Manage Subscription button
                    Button(action: {
                        showManage = true
                    }) {
                        Text("Manage Subscription")
                            .font(.interBody)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Restore Purchases
                    Button(action: {
                        Task {
                            await subscriptionManager.restore()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                    }
                }
            } else {
                // Not subscribed state
                VStack(alignment: .leading, spacing: 12) {
                    Text("You're currently on the Free Plan")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveText)
                    
                    Button(action: {
                        showingPaywall = true
                    }) {
                        Text("Upgrade to Flare Pro")
                            .font(.interBody)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    // Restore Purchases
                    Button(action: {
                        Task {
                            await subscriptionManager.restore()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                    }
                }
            }
            
            // Error message
            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
                    .font(.interCaption)
                    .foregroundColor(.red)
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .sheet(isPresented: $showingPaywall) {
            NavigationView {
                PaywallPlaceholderView(onStartFreeWeek: {
                    showingPaywall = false
                })
                .environmentObject(subscriptionManager)
            }
        }
        .sheet(isPresented: $showManage) {
            #if canImport(RevenueCatUI)
            NavigationView {
                CustomerCenterView()
                    .navigationTitle("Manage Subscription")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showManage = false
                            }
                        }
                    }
            }
            #elseif canImport(RevenueCat)
            NavigationView {
                VStack(spacing: 16) {
                    Image(systemName: "info.circle")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    Text("Subscription Management")
                        .font(.interHeadline)
                    
                    Text("RevenueCat is added, but RevenueCatUI is missing.\n\nPlease add the RevenueCatUI product to your target in Xcode.")
                        .font(.interBody)
                        .foregroundColor(.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Done") {
                        showManage = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
                .navigationTitle("Manage Subscription")
                .navigationBarTitleDisplayMode(.inline)
            }
            #else
            NavigationView {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Subscription Management")
                        .font(.interHeadline)
                    
                    Text("Please add RevenueCat package to enable subscription management.")
                        .font(.interBody)
                        .foregroundColor(.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Done") {
                        showManage = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
                .navigationTitle("Manage Subscription")
                .navigationBarTitleDisplayMode(.inline)
            }
            #endif
        }
        .task {
            // Refresh subscription status when view appears
            await subscriptionManager.checkEntitlements()
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
