import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager()
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab: Tab = .home
    @Namespace private var tabAnimation
    
    private enum Tab: Int, CaseIterable {
        case home
        case settings
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .settings: return "Settings"
            }
        }
        
        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        // Allow app access without authentication per App Store Guideline 5.1.1
        // Pre-login view shows current weather (non-account-based feature)
        // Personalized insights require login (account-based feature)
        // Don't switch views if onboarding is in progress (prevents dismissing onboarding flow)
        if authManager.isAuthenticated && !authManager.isOnboardingInProgress {
            ZStack(alignment: .bottom) {
                Color.adaptiveBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ZStack {
                        if selectedTab == .home {
                            HomeView()
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .id(Tab.home)
                        } else {
                            SettingsView()
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .leading)),
                                    removal: .opacity.combined(with: .move(edge: .trailing))
                                ))
                                .id(Tab.settings)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.2), value: selectedTab)
                    
                    customTabBar
                        .padding(.bottom, 16)
                        .padding(.horizontal, 12)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
        } else {
            // Show pre-login view when not authenticated
            PreLoginView()
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 12) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.adaptiveCardBackground.opacity(0.9))
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    private func tabButton(for tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8, blendDuration: 0.2)) {
                selectedTab = tab
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? Color.adaptiveText : Color.adaptiveMuted)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                Text(tab.title)
                    .font(.interCaption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? Color.adaptiveText : Color.adaptiveMuted.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.adaptiveText.opacity(0.12))
                            .matchedGeometryEffect(id: "tabHighlight", in: tabAnimation)
                            .transition(.opacity)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
