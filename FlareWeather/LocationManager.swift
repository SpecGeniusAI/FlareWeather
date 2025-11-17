import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation? {
        didSet {
            if useDeviceLocation, let newLocation = location {
                print("📡 LocationManager: location updated to \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
                updateDeviceLocationName(for: newLocation)
            }
        }
    }
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var manualLocationName: String? = UserDefaults.standard.string(forKey: "manualLocation")
    @Published var deviceLocationName: String? = UserDefaults.standard.string(forKey: "deviceLocationName")
    @Published var useDeviceLocation: Bool = true {
        didSet {
            UserDefaults.standard.set(useDeviceLocation, forKey: "useDeviceLocation")
            if useDeviceLocation {
                manualLocationName = nil
                if let currentLocation = location {
                    updateDeviceLocationName(for: currentLocation)
                } else {
                    requestLocation()
                }
            } else {
                deviceLocationName = nil
                UserDefaults.standard.removeObject(forKey: "deviceLocationName")
            }
            loadManualLocation()
        }
    }
    
    private let geocoder = CLGeocoder()
    
    private var manualLocation: String {
        UserDefaults.standard.string(forKey: "manualLocation") ?? ""
    }
    
    override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        // Load saved preference (defaults to true if not set)
        let savedPreference = UserDefaults.standard.object(forKey: "useDeviceLocation") as? Bool ?? true
        useDeviceLocation = savedPreference
        
        // Load manual location if set (useDeviceLocation didSet handles the rest)
        loadManualLocation()
    }
    
    func loadManualLocation() {
        if !useDeviceLocation && !manualLocation.isEmpty {
            manualLocationName = manualLocation
            let lat = UserDefaults.standard.double(forKey: "manualLocationLat")
            let lon = UserDefaults.standard.double(forKey: "manualLocationLon")
            if lat != 0 && lon != 0 {
                let newLocation = CLLocation(latitude: lat, longitude: lon)
                if let currentLocation = self.location {
                    let distance = currentLocation.distance(from: newLocation)
                    if distance > 100 {
                        print("📍 LocationManager: Manual location changed significantly, updating...")
                        self.location = newLocation
                    }
                } else {
                    self.location = newLocation
                }
                print("✅ LocationManager: Loaded manual location: \(lat), \(lon)")
            } else {
                print("⚠️ LocationManager: Manual location coordinates not found")
            }
        } else if useDeviceLocation {
            manualLocationName = nil
            print("📍 LocationManager: Using device location, clearing manual location")
        } else {
            manualLocationName = nil
        }
    }
    
    private func updateDeviceLocationName(for location: CLLocation) {
        print("🗺️ LocationManager: Reverse geocoding device location...")
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                print("⚠️ LocationManager: Reverse geocode failed - \(error.localizedDescription)")
            }
            if let placemark = placemarks?.first {
                let components = [placemark.locality, placemark.subAdministrativeArea, placemark.administrativeArea, placemark.country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                var name = components.joined(separator: ", ")
                if name.isEmpty {
                    name = placemark.name ?? ""
                }
                DispatchQueue.main.async {
                    let finalName = name.isEmpty ? nil : name
                    self.deviceLocationName = finalName
                    if let finalName {
                        UserDefaults.standard.set(finalName, forKey: "deviceLocationName")
                        print("✅ LocationManager: Device location name -> \(finalName)")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "deviceLocationName")
                        print("⚠️ LocationManager: Reverse geocode returned empty name")
                    }
                }
            } else if error != nil {
                DispatchQueue.main.async {
                    self.deviceLocationName = nil
                    UserDefaults.standard.removeObject(forKey: "deviceLocationName")
                }
            }
        }
    }
    
    func requestLocation() {
        if useDeviceLocation {
            locationManager.requestLocation()
        } else {
            loadManualLocation()
        }
    }
    
    func getCurrentLocation() -> CLLocation? {
        if useDeviceLocation {
            return location
        } else {
            // Return manual location
            loadManualLocation()
            return location
        }
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard useDeviceLocation else {
            return
        }
        guard let location = locations.last else {
            print("⚠️ LocationManager: No location in locations array")
            return
        }
        print("✅ LocationManager: Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        self.location = location
        updateDeviceLocationName(for: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: Error - \(error.localizedDescription)")
        errorMessage = error.localizedDescription
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 LocationManager: Authorization status changed to: \(status.rawValue)")
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ LocationManager: Authorized, requesting location...")
            locationManager.requestLocation()
        case .denied, .restricted:
            print("❌ LocationManager: Location access denied")
            errorMessage = "Location access denied"
        case .notDetermined:
            print("📍 LocationManager: Status not determined, requesting authorization...")
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}
