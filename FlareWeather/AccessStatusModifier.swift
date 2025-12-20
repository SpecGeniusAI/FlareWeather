import SwiftUI

struct AccessStatusModifier: ViewModifier {
    let authManager: AuthManager
    let hasInitialAnalysis: Bool
    let hasGeneratedDailyInsightSession: Bool
    let lastDiagnosesHash: String?
    let handleUserProfileChange: () -> Void
    let checkAccessStatus: () -> Void
    let refreshUserInfoAndCheckAccess: () -> Void
    @Binding var showingOnboarding: Bool
    @Binding var showingPaywall: Bool
    @Binding var showingAccessExpiredPopup: Bool
    let subscriptionManager: SubscriptionManager
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if (hasInitialAnalysis || hasGeneratedDailyInsightSession) && lastDiagnosesHash != nil {
                    handleUserProfileChange()
                }
                checkAccessStatus()
                refreshUserInfoAndCheckAccess()
            }
            .onChange(of: authManager.currentUser) {
                checkAccessStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccessRequired"))) { _ in
                refreshUserInfoAndCheckAccess()
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingFlowView()
                    .environmentObject(authManager)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showingPaywall) {
                NavigationView {
                    PaywallPlaceholderView(onStartFreeWeek: {
                        showingPaywall = false
                    })
                }
            }
            .overlay {
                accessExpiredOverlay
            }
    }
    
    @ViewBuilder
    private var accessExpiredOverlay: some View {
        if showingAccessExpiredPopup {
            ZStack {
                // Blurred and dimmed background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Don't allow dismissing by tapping outside
                    }
                
                AccessExpiredPopupView(
                    expired: authManager.currentUser?.access_expired == true,
                    logoutMessage: authManager.currentUser?.logout_message,
                    onSubscribe: {
                        showingAccessExpiredPopup = false
                        showingPaywall = true
                    },
                    onLogout: {
                        showingAccessExpiredPopup = false
                        authManager.logout()
                    }
                )
            }
        }
    }
}
