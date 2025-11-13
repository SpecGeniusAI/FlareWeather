import SwiftUI
import CoreData
import CoreLocation
import MapKit
import Combine

// Location search manager for autocomplete
class LocationSearchManager: NSObject, ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    
    private let searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.4284, longitude: -123.3656), // Default to Victoria, BC area
            span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
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
    
    private func updateSearchQuery(_ query: String) {
        if query.isEmpty {
            searchResults = []
            isSearching = false
        } else {
            searchCompleter.queryFragment = query
            isSearching = true
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
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("❌ Search completer error: \(error.localizedDescription)")
        isSearching = false
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: false)],
        animation: .default)
    private var userProfiles: FetchedResults<UserProfile>
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var themeManager = ThemeManager()
    @EnvironmentObject var authManager: AuthManager
    @State private var showingOnboarding = false
    @State private var showingLocationSettings = false
    @State private var showingProfileEdit = false
    
    var currentUser: UserProfile? {
        userProfiles.first
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
                                    
                                    HStack {
                                        Text("Age")
                                            .font(.interBody)
                                            .foregroundColor(Color.adaptiveMuted)
                                        Spacer()
                                        Text("\(user.age)")
                                            .font(.interBody)
                                            .foregroundColor(Color.adaptiveText)
                                    }
                                    
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
                    
                    // Logout Button
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
        }
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
                                        }
                                        .background(Color.adaptiveBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isSearchFieldFocused ? Color.adaptiveCardBackground : Color.clear, lineWidth: 2)
                                        )
                                        
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
            }
        }
    }
}

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    var user: UserProfile
    
    @State private var name: String
    @State private var age: Int
    @State private var selectedDiagnoses: Set<String> = []
    @State private var otherDiagnosis = ""
    
    let commonDiagnoses = [
        "Arthritis",
        "Fibromyalgia",
        "Migraine",
        "Chronic Pain",
        "Asthma",
        "COPD",
        "Allergies",
        "Depression",
        "Anxiety",
        "Multiple Sclerosis",
        "Lupus",
        "Other"
    ]
    
    init(user: UserProfile) {
        self.user = user
        _name = State(initialValue: user.name ?? "")
        _age = State(initialValue: Int(user.age))
        // Load existing diagnoses
        if let diagnosesArray = user.value(forKey: "diagnoses") as? NSArray,
           let diagnoses = diagnosesArray as? [String] {
            _selectedDiagnoses = State(initialValue: Set(diagnoses))
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
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Age")
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveText)
                                    Spacer()
                                    Text("\(age)")
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveText)
                                }
                                Slider(value: Binding(
                                    get: { Double(age) },
                                    set: { age = Int($0) }
                                ), in: 18...100, step: 1)
                                .accentColor(Color.adaptiveCardBackground)
                            }
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
                                            Image(systemName: selectedDiagnoses.contains(diagnosis) ? "checkmark" : "")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(selectedDiagnoses.contains(diagnosis) ? Color.adaptiveText : Color.clear)
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
                                        Image(systemName: selectedDiagnoses.contains("Other") ? "checkmark" : "")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(selectedDiagnoses.contains("Other") ? Color.adaptiveText : Color.clear)
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
        }
    }
    
    private func saveProfile() {
        user.setValue(name, forKey: "name")
        user.setValue(Int32(age), forKey: "age")
        // Store diagnoses as array
        let diagnosesArray = Array(selectedDiagnoses).filter { $0 != "Other" && !$0.isEmpty }
        user.setValue(diagnosesArray, forKey: "diagnoses")
        user.setValue(Date(), forKey: "updatedAt")
        
        do {
            try viewContext.save()
            print("✅ Updated user profile. Diagnoses: \(diagnosesArray)")
            dismiss()
        } catch {
            print("❌ Error saving profile: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
