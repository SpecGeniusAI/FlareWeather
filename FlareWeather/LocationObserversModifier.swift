import SwiftUI
import CoreLocation

struct LocationObserversModifier: ViewModifier {
    let locationManager: LocationManager
    let weatherService: WeatherService
    let aiService: AIInsightsService
    let scenePhase: ScenePhase
    let handleViewAppearAction: () -> Void
    let handleLocationChange: (CLLocation?) -> Void
    let handleLocationPreferenceChange: (Bool) -> Void
    let handleWeatherDataChange: (WeatherData?, WeatherData?) -> Void
    let handleAuthorizationStatusChange: (CLAuthorizationStatus) -> Void
    let handleScenePhaseChange: (ScenePhase, ScenePhase) -> Void
    @Binding var aiFeedback: Bool?
    
    func body(content: Content) -> some View {
        content
            .onAppear(perform: handleViewAppearAction)
            .onChange(of: locationManager.location) { _, new in
                handleLocationChange(new)
            }
            .onChange(of: locationManager.useDeviceLocation) { _, new in
                handleLocationPreferenceChange(new)
            }
            .onChange(of: weatherService.weatherData) { old, new in
                handleWeatherDataChange(old, new)
            }
            .onChange(of: locationManager.authorizationStatus) { _, new in
                handleAuthorizationStatusChange(new)
            }
            .onChange(of: aiService.isLoading) { _, new in
                if new { aiFeedback = nil }
            }
            .onChange(of: aiService.insightMessage) { old, new in
                if old != new { aiFeedback = nil }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(oldPhase, newPhase)
            }
    }
}
