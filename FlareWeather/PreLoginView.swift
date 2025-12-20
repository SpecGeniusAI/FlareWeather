import SwiftUI
import CoreLocation

struct PreLoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var weatherService = WeatherService()
    @StateObject private var locationManager = LocationManager()
    @State private var showingLogin = false
    @State private var showingOnboarding = false
    @State private var showingBanner = false
    @State private var usingFallbackWeather = false
    @State private var weatherFetchTask: Task<Void, Never>?
    @AppStorage("lastPopupDate") private var lastPopupDateString: String = ""
    @AppStorage("firstAppOpenDate") private var firstAppOpenDateString: String = ""
    
    // Fallback location: Seattle, WA
    private let fallbackLocation = CLLocation(latitude: 47.6062, longitude: -122.3321)
    private let fallbackLocationName = "Seattle, WA"
    
    // Get location name for display - always show fallback location name when using fallback
    private var locationName: String? {
        if usingFallbackWeather {
            return fallbackLocationName // "Seattle, WA"
        } else if !locationManager.useDeviceLocation {
            return locationManager.manualLocationName ?? UserDefaults.standard.string(forKey: "manualLocation")
        } else {
            // Try device location name first, then weather data location, then fallback
            return locationManager.deviceLocationName 
                ?? weatherService.weatherData?.location 
                ?? fallbackLocationName
        }
    }
    
    private func getEffectiveLocation() -> CLLocation? {
        let location = locationManager.getCurrentLocation()
        return location ?? fallbackLocation // Use fallback if no location available
    }
    
    // Create fallback weather data (Seattle, WA)
    private func createFallbackWeather() {
        let fallbackData = WeatherData(
            temperature: 15.0,
            humidity: 65.0,
            pressure: 1013.0,
            windSpeed: 10.0,
            condition: "Partly Cloudy",
            timestamp: Date(),
            location: fallbackLocationName,
            airQuality: 2
        )
        weatherService.weatherData = fallbackData
        
        // Hourly and weekly forecasts not shown on pre-login screen, so skip creating them
        
        weatherService.isLoading = false
        weatherService.isLoadingForecast = false
        weatherService.isLoadingHourly = false
        weatherService.errorMessage = nil
        usingFallbackWeather = true
        print("🔄 PreLoginView: Using fallback weather data for \(fallbackLocationName)")
    }
    
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Logo - centered
                        Image(colorScheme == .dark ? "LogoLight" : "LogoDark")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 16)
                            .padding(.horizontal)
                            .opacity(showingBanner ? 0 : 1)
                            .animation(.easeInOut(duration: 0.3), value: showingBanner)
                    
                    // WEATHER CARDS (always shown - real or fallback)
                    // 1. Current Weather Card
                    WeatherCardView(
                        weatherData: weatherService.weatherData,
                        isLoading: weatherService.isLoading && !usingFallbackWeather,
                        errorMessage: nil, // Never show error messages - use fallback instead
                        locationName: locationName
                    )
                    .padding(.horizontal)
                    
                    // 2. Sample Daily Insight Card (static, generic - NOT personalized)
                    SampleDailyInsightCardView()
                        .padding(.horizontal)
                    
                    // Apple Weather Attribution (immediately after weather cards)
                    AppleWeatherAttributionView()
                        .padding(.horizontal)
                        .padding(.top, 4) // Reduced spacing
                    
                    // Login / Sign Up Button (last element)
                    Button(action: {
                        showingLogin = true
                    }) {
                        Text("Login / Sign Up")
                            .font(.interBody.weight(.semibold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#2d3240") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14) // Slightly reduced
                            .background(Color.adaptiveAccent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4) // Reduced spacing
                    .padding(.bottom, 16) // Reduced bottom padding
                    }
                    .padding(.vertical, 12) // Reduced vertical padding
                }
                .background(Color.adaptiveBackground.ignoresSafeArea())
                
                // Green subscription banner - overlays welcome header position exactly
                if showingBanner {
                    HStack(alignment: .top, spacing: 0) {
                        SubscriptionBannerView {
                            showingOnboarding = true
                        }
                        .padding(.top, 16)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LogoWordmarkView()
                }
            }
            .onAppear {
                // Immediately load fallback weather to ensure something is always shown
                createFallbackWeather()
                
                // Request location and fetch real weather
                locationManager.requestLocation()
                loadWeatherWithTimeout()
                
                // Check if it's a popup day first, then show banner or popup accordingly
                let isPopupDay = checkIfPopupDay()
                if !isPopupDay {
                    checkAndShowBanner()
                }
            }
            .onChange(of: locationManager.location) { _, new in
                guard let location = new else { return }
                // Location was granted and received - update weather from fallback to real location
                loadWeatherForLocation(location)
            }
            .onChange(of: locationManager.authorizationStatus) { _, new in
                // When permission is granted, requestLocation will be called by LocationManager
                // and then onChange(of: location) will trigger the weather update
                if new == .authorizedWhenInUse || new == .authorizedAlways {
                    print("📍 PreLoginView: Location permission granted, waiting for location...")
                }
            }
            .onDisappear {
                // Cancel any pending weather fetch tasks
                weatherFetchTask?.cancel()
                weatherFetchTask = nil
            }
            .fullScreenCover(isPresented: $showingLogin) {
                LoginView()
                    .environmentObject(authManager)
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingFlowView()
                    .environmentObject(authManager)
                    .environmentObject(subscriptionManager)
            }
        }
    }
    
    private func checkIfPopupDay() -> Bool {
        // Only check for non-authenticated users
        guard !authManager.isAuthenticated else {
            return false
        }
        
        let today = Date()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)
        
        // Set first app open date if not set
        if firstAppOpenDateString.isEmpty {
            firstAppOpenDateString = todayString
            return false // Don't show popup on first day
        }
        
        guard let firstAppOpenDate = dateFormatter.date(from: firstAppOpenDateString) else {
            return false
        }
        
        // Calculate days since first app open
        let daysSinceFirstOpen = calendar.dateComponents([.day], from: firstAppOpenDate, to: today).day ?? 0
        
        // Popup shows on day 3, then every 2nd day after (3, 5, 7, 9, etc.)
        if daysSinceFirstOpen >= 3 {
            let isPopupDay = (daysSinceFirstOpen - 3) % 2 == 0
            
            // Check if we already showed popup today
            if let lastPopupDateString = lastPopupDateString.isEmpty ? nil : lastPopupDateString,
               lastPopupDateString == todayString {
                return false
            }
            
            return isPopupDay
        }
        
        return false
    }
    
    private func checkAndShowBanner() {
        // Only show banner for non-authenticated users on non-popup days
        guard !authManager.isAuthenticated else {
            return
        }
        
        // Show banner after 3 second delay with smooth animation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds delay
            if !authManager.isAuthenticated {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingBanner = true
                }
            }
        }
    }
    
    // Load weather with 2-second timeout - fallback to Seattle if timeout or failure
    private func loadWeatherWithTimeout() {
        weatherFetchTask?.cancel()
        
        weatherFetchTask = Task {
            let location = getEffectiveLocation() ?? fallbackLocation
            
            // Try to fetch real weather (non-blocking)
            Task {
                await weatherService.fetchWeatherData(for: location, forceRefresh: true)
                // Hourly and weekly forecasts not shown on pre-login screen, so skip fetching them
                
                // If fetch succeeded, update state (fallback was already loaded, so this replaces it)
                if !Task.isCancelled {
                    await MainActor.run {
                        usingFallbackWeather = false
                    }
                }
            }
            
            // Wait 2 seconds - after this, if no real weather loaded, fallback remains shown
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            // After timeout, ensure fallback is still shown if no real weather loaded
            if !Task.isCancelled {
                await MainActor.run {
                    if weatherService.weatherData == nil || usingFallbackWeather {
                        // Fallback should already be loaded, but ensure it's visible
                        if weatherService.weatherData == nil {
                            createFallbackWeather()
                        }
                    }
                }
            }
        }
    }
    
    // Load weather for a specific location (called when location changes)
    // This updates from fallback weather to real location weather
    private func loadWeatherForLocation(_ location: CLLocation) {
        weatherFetchTask?.cancel()
        
        weatherFetchTask = Task {
            await weatherService.fetchWeatherData(for: location, forceRefresh: true)
            // Hourly and weekly forecasts not shown on pre-login screen, so skip fetching them
            
            // Update state on main actor to switch from fallback to real weather
            if !Task.isCancelled {
                await MainActor.run {
                    usingFallbackWeather = false
                    print("✅ PreLoginView: Updated from fallback to real location weather")
                }
            }
        }
    }
}

// Sample Daily Insight Card for Pre-Login View (static, generic - NOT personalized)
// ONLY used on pre-login screen - shows a simple static sample insight
// Uses same styling as WeatherCardView via .cardStyle()
private struct SampleDailyInsightCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Insight (Sample)")
                        .font(.interHeadline)
                        .foregroundColor(Color.adaptiveText)
                    Text("General Weather Insights")
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                }
                
                Spacer()
            }
            
            // Summary
            Text("Steady weather today with mild shifts that most people experience as low impact.")
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            
            // Comfort tip (Eastern medicine style)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                Text("Comfort tip: Chinese medicine suggests gentle qigong movements to ease joint stiffness during weather shifts.")
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            
            Text("Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.")
                .font(.interSmall)
                .foregroundColor(Color.adaptiveMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .cardStyle()
    }
}

// Sample Weekly Insight Card for Pre-Login View (static, generic - NOT personalized)
// Matches the format of WeeklyForecastInsightCardView
private struct SampleWeeklyInsightCardView: View {
    @Environment(\.colorScheme) var colorScheme
    
    private let sampleSummary = "A mostly steady week ahead with consistent conditions."
    private let sampleDays: [WeeklyInsightDay] = [
        WeeklyInsightDay(label: "Thu", detail: "Low flare risk — steady pressure"),
        WeeklyInsightDay(label: "Fri", detail: "Low flare risk — stable pattern"),
        WeeklyInsightDay(label: "Sat", detail: "Low flare risk — predictable day"),
        WeeklyInsightDay(label: "Sun", detail: "Low flare risk — cool, calm air"),
        WeeklyInsightDay(label: "Mon", detail: "Low flare risk — gentle humidity"),
        WeeklyInsightDay(label: "Tue", detail: "Low flare risk — smooth conditions"),
        WeeklyInsightDay(label: "Wed", detail: "Low flare risk — easy-going pattern")
    ]
    
    private func formatWeekdayLabel(_ label: String) -> String {
        let lowercased = label.lowercased()
        if lowercased == "mon" || lowercased == "tue" || lowercased == "wed" || lowercased == "thu" || lowercased == "fri" || lowercased == "sat" || lowercased == "sun" {
            return label.prefix(1).uppercased() + label.dropFirst().lowercased() + "."
        }
        return label
    }
    
    private func extractRiskLevel(_ detail: String) -> String {
        let lowerDetail = detail.lowercased()
        if lowerDetail.contains("high") || lowerDetail.contains("elevated") || lowerDetail.contains("severe") {
            return "High"
        } else if lowerDetail.contains("moderate") || lowerDetail.contains("moderate risk") {
            return "Moderate"
        } else {
            return "Low"
        }
    }
    
    private func removeRiskLevelFromDetail(_ detail: String) -> String {
        let cleaned = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let dashPatterns = [" — ", " – ", " - "]
        
        for dashPattern in dashPatterns {
            if let dashRange = cleaned.range(of: dashPattern) {
                let afterDash = String(cleaned[dashRange.upperBound...])
                let descriptor = afterDash.trimmingCharacters(in: .whitespacesAndNewlines)
                if !descriptor.isEmpty {
                    return descriptor
                }
            }
        }
        
        return cleaned.isEmpty ? detail : cleaned
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: "Weekly Insight" (matching design)
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                Text("Weekly Insight (Sample)")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
            }
            
            // Weekly summary
            Text(sampleSummary)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            
            // Daily breakdown
            Divider()
                .background(Color.adaptiveMuted.opacity(0.15))
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sampleDays) { day in
                    HStack(alignment: .top, spacing: 12) {
                        // Weekday label
                        Text(formatWeekdayLabel(day.label))
                            .font(.interBody)
                            .fontWeight(.bold)
                            .foregroundColor(Color.adaptiveText)
                            .frame(width: 48, alignment: .leading)
                        
                        // Detail text with risk level
                        HStack(alignment: .top, spacing: 6) {
                            let riskLevel = extractRiskLevel(day.detail)
                            let riskColor: Color = {
                                switch riskLevel {
                                case "High": 
                                    return Color.riskHigh
                                case "Moderate": 
                                    return Color.riskModerate
                                default: 
                                    return Color.riskLow
                                }
                            }()
                            
                            let backgroundColor: Color = {
                                switch riskLevel {
                                case "High": 
                                    return Color.riskHighBackground
                                case "Moderate": 
                                    return Color.riskModerateBackground
                                default: 
                                    return Color.riskLowBackground
                                }
                            }()
                            
                            Text(riskLevel)
                                .font(.interBody)
                                .fontWeight(.bold)
                                .foregroundColor(riskColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(backgroundColor)
                                .cornerRadius(6)
                            
                            let cleanedDetail = removeRiskLevelFromDetail(day.detail)
                            if !cleanedDetail.isEmpty {
                                Text(cleanedDetail)
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveMuted)
                            } else {
                                let defaultDescriptor: String = {
                                    switch riskLevel {
                                    case "High": return "challenging conditions"
                                    case "Moderate": return "noticeable shifts"
                                    default: return "steady conditions"
                                    }
                                }()
                                Text(defaultDescriptor)
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveMuted)
                            }
                        }
                    }
                }
            }
            
            Text("Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.")
                .font(.interSmall)
                .foregroundColor(Color.adaptiveMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .cardStyle()
    }
}

// Reuse the Apple Weather Attribution View from HomeView
private struct AppleWeatherAttributionView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            // Apple Weather trademark - display Apple logo symbol and "Weather"
            HStack(spacing: 2) {
                Text("Weather data provided by")
                    .font(.interSmall)
                    .foregroundColor(Color.adaptiveMuted)
                // Use SF Symbol for Apple logo if available, otherwise use text
                Image(systemName: "applelogo")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.adaptiveMuted)
                Text("Weather")
                    .font(.interSmall)
                    .foregroundColor(Color.adaptiveMuted)
            }
            
            // Legal attribution link
            Link("Legal Attribution", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                .font(.interSmall)
                .foregroundColor(Color.adaptiveAccent)
                .underline()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }
}

// Reuse the Logo Wordmark View from HomeView
private struct LogoWordmarkView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Image(colorScheme == .dark ? "LogoLight" : "LogoDark")
            .resizable()
            .scaledToFit()
            .frame(height: 22)
            .accessibilityLabel("FlareWeather")
    }
}

#Preview {
    PreLoginView()
        .environmentObject(AuthManager())
        .environmentObject(SubscriptionManager.shared)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

