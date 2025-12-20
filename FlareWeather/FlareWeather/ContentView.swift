import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager()
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        // Allow app access without authentication per App Store Guideline 5.1.1
        // Pre-login view shows current weather (non-account-based feature)
        // Personalized insights require login (account-based feature)
        // Don't switch views if onboarding is in progress (prevents dismissing onboarding flow)
        if authManager.isAuthenticated && !authManager.isOnboardingInProgress {
            HomeView()
                .preferredColorScheme(themeManager.colorScheme)
        } else {
            // Show pre-login view when not authenticated
            PreLoginView()
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
