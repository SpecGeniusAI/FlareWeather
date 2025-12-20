import SwiftUI
import CoreLocation

struct LocationChangeModifier: ViewModifier {
    let locationManager: LocationManager
    let weatherService: WeatherService
    let aiService: AIInsightsService
    let scenePhase: ScenePhase
    let authManager: AuthManager
    let handleViewAppearAction: () -> Void
    let handleLocationChange: (CLLocation?) -> Void
    let handleLocationPreferenceChange: (Bool) -> Void
    let handleWeatherDataChange: (WeatherData?, WeatherData?) -> Void
    let handleAuthorizationStatusChange: (CLAuthorizationStatus) -> Void
    let handleScenePhaseChange: (ScenePhase, ScenePhase) -> Void
    let hasInitialAnalysis: Bool
    let hasGeneratedDailyInsightSession: Bool
    let lastDiagnosesHash: String?
    let handleUserProfileChange: () -> Void
    let checkAccessStatus: () -> Void
    let refreshUserInfoAndCheckAccess: () -> Void
    @Binding var aiFeedback: Bool?
    @Binding var showingOnboarding: Bool
    @Binding var showingPaywall: Bool
    @Binding var showingAccessExpiredPopup: Bool
    let subscriptionManager: SubscriptionManager
    
    func body(content: Content) -> some View {
        content
            .modifier(LocationObserversModifier(
                locationManager: locationManager,
                weatherService: weatherService,
                aiService: aiService,
                scenePhase: scenePhase,
                handleViewAppearAction: handleViewAppearAction,
                handleLocationChange: handleLocationChange,
                handleLocationPreferenceChange: handleLocationPreferenceChange,
                handleWeatherDataChange: handleWeatherDataChange,
                handleAuthorizationStatusChange: handleAuthorizationStatusChange,
                handleScenePhaseChange: handleScenePhaseChange,
                aiFeedback: $aiFeedback
            ))
            .modifier(AccessStatusModifier(
                authManager: authManager,
                hasInitialAnalysis: hasInitialAnalysis,
                hasGeneratedDailyInsightSession: hasGeneratedDailyInsightSession,
                lastDiagnosesHash: lastDiagnosesHash,
                handleUserProfileChange: handleUserProfileChange,
                checkAccessStatus: checkAccessStatus,
                refreshUserInfoAndCheckAccess: refreshUserInfoAndCheckAccess,
                showingOnboarding: $showingOnboarding,
                showingPaywall: $showingPaywall,
                showingAccessExpiredPopup: $showingAccessExpiredPopup,
                subscriptionManager: subscriptionManager
            ))
    }
}
