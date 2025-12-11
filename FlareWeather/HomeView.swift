import SwiftUI
import CoreLocation
import CoreData

// Helper extension for temperature conversion
extension Double {
    func toTemperatureString(useFahrenheit: Bool = false) -> String {
        let useF = UserDefaults.standard.bool(forKey: "useFahrenheit")
        let converted = useF ? (self * 9/5) + 32 : self
        let unit = useF ? "F" : "C"
        return "\(Int(converted))°\(unit)"
    }
    
    func toTemperature(useFahrenheit: Bool = false) -> Double {
        let useF = UserDefaults.standard.bool(forKey: "useFahrenheit")
        return useF ? (self * 9/5) + 32 : self
    }
    
    var temperatureUnit: String {
        UserDefaults.standard.bool(forKey: "useFahrenheit") ? "F" : "C"
    }
}

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var weatherService = WeatherService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var aiService = AIInsightsService()
    @State private var showingOnboarding = false
    @State private var lastRefreshTime: Date? = nil
    @State private var aiFeedback: Bool? = nil
    @State private var hasInitialAnalysis = false
    @State private var isManualInsightRefresh = false
    @State private var lastDiagnosesHash: String? = nil
    @State private var lastSensitivitiesHash: String? = nil
    @State private var shouldLoadWeeklyData = false // Lazy loading flag for weekly forecast and insights
    @State private var lastForegroundDate: Date? = nil
    @State private var showingPaywall = false
    @State private var showingAccessExpiredPopup = false
    @AppStorage("useFahrenheit") private var useFahrenheit = false
    @AppStorage("hasGeneratedDailyInsightSession") private var hasGeneratedDailyInsightSession = false
    @AppStorage("lastInsightDate") private var lastInsightDateString: String = ""
    
    // Helper function to refresh analysis
    private func refreshAnalysis(force: Bool = false, includeWeeklyForecast: Bool = false) async {
        // The AIInsightsService now handles caching based on input changes
        // So we can call it more freely - it will only analyze if inputs changed
        
        print("🔄 HomeView: Refreshing analysis (includeWeeklyForecast: \(includeWeeklyForecast))...")
        
        // Fetch user profile for diagnoses
        let userRequest: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        userRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: false)]
        let userProfile = try? viewContext.fetch(userRequest).first
        
        await aiService.analyzeWithWeatherOnly(
            weatherService: weatherService,
            userProfile: userProfile,
            force: force,
            includeWeeklyForecast: includeWeeklyForecast
        )
        
        lastRefreshTime = Date()
    }
    
    // Handle view appear
    private func handleViewAppear() {
        print("🏠 HomeView: Appeared")
        print("📍 HomeView: Location auth status: \(locationManager.authorizationStatus.rawValue)")
        print("📍 HomeView: useDeviceLocation: \(locationManager.useDeviceLocation)")
        print("🧠 HomeView: Has initial analysis: \(hasInitialAnalysis)")
        print("🧠 HomeView: hasGeneratedDailyInsightSession: \(hasGeneratedDailyInsightSession)")
        
        // Request location (will use manual if set)
        locationManager.requestLocation()
        
        // OPTIMIZATION: Background pre-fetching - start analysis in background if we have weather data
        // This makes insights appear faster when user opens the app
        if weatherService.weatherData != nil && !hasInitialAnalysis && !hasGeneratedDailyInsightSession {
            print("🚀 Starting background pre-fetch of insights...")
            Task {
                // Small delay to let UI render first, then start analysis
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if getEffectiveLocation() != nil {
                    // Fetch user profile for diagnoses
                    let userRequest: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
                    userRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: false)]
                    let userProfile = try? viewContext.fetch(userRequest).first
                    
                    await aiService.analyzeWithWeatherOnly(
                        weatherService: weatherService,
                        userProfile: userProfile,
                        force: false,
                        includeWeeklyForecast: false
                    )
                }
            }
        }
        
        // Initialize profile hashes on first appear
        if lastDiagnosesHash == nil {
            lastDiagnosesHash = getUserProfileHash()
            lastSensitivitiesHash = getUserProfileHash() // Same hash includes both
        }
        
        // Check access status when user info is available
        checkAccessStatus()
        
        // Check if aiService already has valid insights (persists across navigation)
        let hasExistingInsights = (aiService.insightMessage != "Analyzing your week…" && 
                                  aiService.insightMessage != "Analyzing weather patterns…" && 
                                  aiService.insightMessage != "Updating analysis…" && 
                                  !aiService.insightMessage.isEmpty) ||
                                 (aiService.weeklyInsightSummary != nil && !aiService.weeklyInsightSummary!.isEmpty) ||
                                 (aiService.risk != nil)
        
        // STRICT: Always fetch weather if we don't have weather data
        // Insights can persist, but weather data is still needed for display
        if weatherService.weatherData == nil {
            print("🌤️ HomeView: No weather data, fetching...")
            Task {
                // Wait for location to be available (with retry)
                var location: CLLocation? = nil
                var retryCount = 0
                let maxRetries = 10 // Try for up to 5 seconds (10 * 0.5s)
                
                while location == nil && retryCount < maxRetries {
                    location = getEffectiveLocation()
                    if location == nil {
                        print("⏳ HomeView: Waiting for location... (attempt \(retryCount + 1)/\(maxRetries))")
                        try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                        retryCount += 1
                    }
                }
                
                if let location = location {
                    print("📍 HomeView: Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    // Fetch current weather - handleWeatherDataChange will trigger analysis IMMEDIATELY when data arrives
                    await weatherService.fetchWeatherData(for: location, forceRefresh: !hasInitialAnalysis)
                    
                    // Fetch hourly forecast in background (don't block analysis)
                    // Weekly forecast will be lazy loaded after daily insight is shown
                    Task.detached(priority: .background) {
                        await weatherService.fetchHourlyForecast(for: location)
                    }
                } else {
                    print("⚠️ HomeView: No location available after \(maxRetries) attempts")
                    // Set loading to false so UI doesn't spin forever
                    await MainActor.run {
                        weatherService.isLoading = false
                    }
                }
            }
        } else {
            // Have weather data - check if we need to trigger analysis
            if (!hasInitialAnalysis && !hasGeneratedDailyInsightSession) && !hasExistingInsights {
                print("🌤️ HomeView: Have weather data but no insights, will trigger analysis when weather change detected")
            } else {
                print("⏭️ HomeView: Already have weather data and insights, skipping fetching")
                // If we already have insights, enable weekly data loading
                if hasExistingInsights {
                    shouldLoadWeeklyData = true
                }
            }
        }
    }
    
    // Handle location change
    private func handleLocationChange(_ new: CLLocation?) {
        guard let location = new else { return }
        
        // Don't trigger if we already have analysis (prevents retrigger on login/navigation)
        guard !hasInitialAnalysis && !hasGeneratedDailyInsightSession else {
            print("⏭️ HomeView: Already have analysis, skipping location change handler")
            return
        }
        
        print("🌤️ HomeView: Location changed to \(location.coordinate.latitude), \(location.coordinate.longitude), fetching weather...")
        Task {
            // Force refresh when location changes to ensure we get fresh data
            await weatherService.fetchWeatherData(for: location, forceRefresh: true)
            // Analysis will be triggered by handleWeatherDataChange when weather arrives
        }
    }
    
    // Get effective location (device or manual)
    private func getEffectiveLocation() -> CLLocation? {
        return locationManager.getCurrentLocation()
    }
    
    // Handle weather data change
    private func handleWeatherDataChange(_ newData: WeatherData?) {
        guard let location = getEffectiveLocation() else { return }
        
        // CRITICAL: Don't trigger analysis if we already have it (prevents retrigger on navigation back)
        // Also check if aiService has valid insights (persists across navigation)
        let hasExistingInsights = (aiService.insightMessage != "Analyzing your week…" && 
                                  aiService.insightMessage != "Analyzing weather patterns…" && 
                                  aiService.insightMessage != "Updating analysis…" && 
                                  !aiService.insightMessage.isEmpty) ||
                                 (aiService.weeklyInsightSummary != nil && !aiService.weeklyInsightSummary!.isEmpty) ||
                                 (aiService.risk != nil)
        
        guard !hasInitialAnalysis && !hasGeneratedDailyInsightSession && !hasExistingInsights else {
            print("⏭️ HomeView: Already have analysis or existing insights, skipping weather data change handler")
            if hasExistingInsights {
                // Sync flags if we have existing insights
                hasInitialAnalysis = true
                hasGeneratedDailyInsightSession = true
            }
            return
        }
        
        print("🌤️ HomeView: Weather data updated")
        print("🧠 HomeView: Has initial analysis: \(hasInitialAnalysis)")
        
        // Start AI analysis IMMEDIATELY with current weather (don't wait for weekly forecast)
        // This is the key optimization - daily insight starts as soon as weather data is available
        // We explicitly exclude weekly forecast to make the API call faster
        print("🚀 HomeView: Starting daily insight analysis IMMEDIATELY with current weather (excluding weekly forecast for speed)...")
        Task {
            // Trigger analysis right away WITHOUT weekly forecast - this is the fast path for daily insight
            await refreshAnalysis(includeWeeklyForecast: false)
            // Mark as complete after analysis finishes
            await MainActor.run {
                hasInitialAnalysis = true
                hasGeneratedDailyInsightSession = true
                // Update insight date
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                lastInsightDateString = formatter.string(from: Date())
                print("✅ HomeView: Daily insight analysis complete, flags set")
                
                // After daily insight is complete, trigger lazy loading of weekly data
                // Small delay to ensure daily insight is displayed first
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    await MainActor.run {
                        shouldLoadWeeklyData = true
                        print("🔄 HomeView: Triggering lazy load of weekly forecast and insights")
                    }
                }
            }
        }
        
        // Fetch hourly forecast in background (for hourly forecast card)
        // Don't fetch weekly forecast yet - it will be lazy loaded
        Task.detached(priority: .background) {
            await weatherService.fetchHourlyForecast(for: location)
        }
    }
    
    // Check if weather data values changed in a noteworthy way (significant differences only)
    // This prevents retriggering on tiny fluctuations
    private func weatherDataValuesChanged(old: WeatherData?, new: WeatherData?) -> Bool {
        guard let old = old, let new = new else {
            return new != nil // New data if old is nil but new exists
        }
        
        // Define thresholds for "noteworthy" changes
        let tempThreshold: Double = 2.0 // 2°C change
        let pressureThreshold: Double = 5.0 // 5 hPa change (significant for symptoms)
        let humidityThreshold: Double = 10.0 // 10% change
        let windThreshold: Double = 5.0 // 5 km/h change
        
        let tempChanged = abs(old.temperature - new.temperature) >= tempThreshold
        let pressureChanged = abs(old.pressure - new.pressure) >= pressureThreshold
        let humidityChanged = abs(old.humidity - new.humidity) >= humidityThreshold
        let windChanged = abs(old.windSpeed - new.windSpeed) >= windThreshold
        
        // Only return true if there's a noteworthy change
        return tempChanged || pressureChanged || humidityChanged || windChanged
    }
    
    // Get hash of user profile (diagnoses and sensitivities) to detect changes
    private func getUserProfileHash() -> String {
        let userRequest: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        userRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: false)]
        guard let userProfile = try? viewContext.fetch(userRequest).first else {
            return "none"
        }
        
        var components: [String] = []
        
        // Add diagnoses
        if let diagnosesArray = userProfile.value(forKey: "diagnoses") as? NSArray,
           let diagnoses = diagnosesArray as? [String], !diagnoses.isEmpty {
            components.append("D:\(diagnoses.sorted().joined(separator: ","))")
        } else {
            components.append("D:none")
        }
        
        // Add sensitivities (stored in UserDefaults)
        if let sensitivities = UserDefaults.standard.array(forKey: "selectedSensitivities") as? [String], !sensitivities.isEmpty {
            components.append("S:\(sensitivities.sorted().joined(separator: ","))")
        } else {
            components.append("S:none")
        }
        
        return components.joined(separator: "|")
    }
    
    // Handle location preference change
    private func handleLocationPreferenceChange(_ new: Bool) {
        print("🔄 HomeView: useDeviceLocation changed to \(new)")
        locationManager.loadManualLocation()
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            if let location = getEffectiveLocation() {
                print("🌤️ HomeView: Refreshing weather for new location preference...")
                await weatherService.fetchWeatherData(for: location, forceRefresh: true)
                // Fetch hourly forecast immediately, weekly will be lazy loaded
                await weatherService.fetchHourlyForecast(for: location)
                await refreshAnalysis(includeWeeklyForecast: false)
                // Reset lazy loading flag to trigger weekly data load after daily insight
                await MainActor.run {
                    shouldLoadWeeklyData = false
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                        await MainActor.run {
                            shouldLoadWeeklyData = true
                        }
                    }
                }
            }
        }
    }
    
    // Handle authorization status change
    private func handleAuthorizationStatusChange(_ new: CLAuthorizationStatus) {
        print("📍 HomeView: Authorization status changed to: \(new.rawValue)")
        if new == .authorizedWhenInUse || new == .authorizedAlways {
            print("✅ HomeView: Authorized, requesting location...")
            locationManager.requestLocation()
        }
    }
    
    // Handle scene phase changes (app going to background/foreground)
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        if newPhase == .active && oldPhase != .active {
            // App came to foreground
            print("🔄 HomeView: App came to foreground")
            handleForegroundRefresh()
            // Refresh user info and check access status when app comes to foreground
            refreshUserInfoAndCheckAccess()
        } else if newPhase == .background {
            // App went to background - save current insight date
            if let insightDate = aiService.insightMessage.isEmpty ? nil : Date() {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                lastInsightDateString = formatter.string(from: insightDate)
            }
        }
    }
    
    // Refresh user info from server and check access status
    private func refreshUserInfoAndCheckAccess() {
        Task {
            do {
                if let token = authManager.accessToken {
                    let authService = AuthService()
                    let userInfo = try await authService.getCurrentUser(token: token)
                    await MainActor.run {
                        authManager.currentUser = userInfo
                        checkAccessStatus()
                    }
                }
            } catch {
                print("⚠️  Failed to refresh user info: \(error)")
            }
        }
    }
    
    // Check if we need to refresh when app comes to foreground
    private func handleForegroundRefresh() {
        let now = Date()
        
        // Check if weather data is stale (older than 30 minutes)
        let weatherIsStale: Bool
        if let weatherData = weatherService.weatherData {
            let age = now.timeIntervalSince(weatherData.timestamp)
            weatherIsStale = age > 30 * 60 // 30 minutes
            print("🌤️ HomeView: Weather data age: \(Int(age / 60)) minutes - Stale: \(weatherIsStale)")
        } else {
            weatherIsStale = true // No weather data
            print("🌤️ HomeView: No weather data - needs refresh")
        }
        
        // Check if insights are stale (different day)
        let insightsAreStale: Bool
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: now)
        insightsAreStale = lastInsightDateString != todayString
        print("🧠 HomeView: Last insight date: \(lastInsightDateString.isEmpty ? "never" : lastInsightDateString), Today: \(todayString) - Stale: \(insightsAreStale)")
        
        // Refresh if data is stale
        if weatherIsStale || insightsAreStale {
            print("🔄 HomeView: Data is stale, refreshing...")
            Task {
                if let location = getEffectiveLocation() {
                    // Refresh weather
                    if weatherIsStale {
                        print("🌤️ HomeView: Refreshing stale weather data...")
                        await weatherService.fetchWeatherData(for: location, forceRefresh: true)
                        await weatherService.fetchHourlyForecast(for: location)
                    }
                    
                    // Refresh insights if stale (new day)
                    if insightsAreStale {
                        print("🧠 HomeView: Refreshing insights for new day...")
                        // Reset flags to allow refresh
                        await MainActor.run {
                            hasInitialAnalysis = false
                            hasGeneratedDailyInsightSession = false
                        }
                        await refreshAnalysis(force: true, includeWeeklyForecast: false)
                        // Update insight date
                        lastInsightDateString = todayString
                    }
                } else {
                    // Request location first
                    locationManager.requestLocation()
                }
            }
        } else {
            print("✅ HomeView: Data is fresh, no refresh needed")
        }
        
        lastForegroundDate = now
    }
    
    // Background - using design system color with dark mode support
    private var backgroundView: some View {
        Color.adaptiveBackground
            .ignoresSafeArea()
    }
    
    // Get location name for display
    private var locationName: String? {
        if !locationManager.useDeviceLocation {
            // Use manual location name if set
            return locationManager.manualLocationName ?? UserDefaults.standard.string(forKey: "manualLocation")
        } else {
            // Prefer reverse geocoded name, fallback to weather service location label
            return locationManager.deviceLocationName ?? weatherService.weatherData?.location
        }
    }

    // Main content view with staggered animations
    private var contentView: some View {
        VStack(spacing: 16) {
            // Sign-up prompt banner (only shown when not authenticated)
            if !authManager.isAuthenticated {
                SignUpPromptBanner(onSignUp: {
                    showingOnboarding = true
                })
                .padding(.horizontal)
                .cardEnterAnimation(delay: -0.1)
            }
            
            // Flare Risk Card
            // Only show loading if we don't have risk data yet (first load)
            // If we have cached risk, keep it visible while updating in background
            FlareRiskCardView(
                risk: aiService.risk,
                forecast: aiService.forecast,
                isLoading: aiService.isLoading && aiService.risk == nil
            )
            .padding(.horizontal)
            .cardEnterAnimation(delay: 0.0)

            if let pressureAlert = aiService.pressureAlert {
                PressureAlertCardView(alert: pressureAlert)
                    .padding(.horizontal)
                    .cardEnterAnimation(delay: 0.05)
            }
            
            // Current Weather Card
            WeatherCardView(
                weatherData: weatherService.weatherData,
                isLoading: weatherService.isLoading,
                errorMessage: weatherService.errorMessage,
                locationName: locationName
            )
            .padding(.horizontal)
            .cardEnterAnimation(delay: 0.1)
            
            // AI Insights Card
            aiInsightsCard
                .cardEnterAnimation(delay: 0.2)
            
                   // Hourly Forecast Card
                   HourlyForecastCardView(
                       forecasts: weatherService.hourlyForecast,
                       isLoading: weatherService.isLoadingHourly,
                       currentPressure: weatherService.weatherData?.pressure
                   )
                   .padding(.horizontal)
                   .cardEnterAnimation(delay: 0.3)

                   // Weekly Forecast Insight Card (lazy loaded - only show when weekly data is ready)
                   // SHOWN BEFORE Weekly Forecast Card
                   let weeklySummary = aiService.weeklyInsightSummary ?? aiService.weeklyForecastInsight
                   if shouldLoadWeeklyData && ((weeklySummary != nil && !(weeklySummary ?? "").isEmpty) || !aiService.weeklyInsightDays.isEmpty) {
                       WeeklyForecastInsightCardView(
                           summary: weeklySummary ?? "",
                           days: aiService.weeklyInsightDays,
                           sources: aiService.weeklyInsightSources
                       )
                           .cardEnterAnimation(delay: 0.4)
                   }

                   // Weekly Forecast Card (lazy loaded - always shown, but data loads lazily)
                   // SHOWN AFTER Weekly Forecast Insight Card
                   WeeklyForecastCardView(
                       forecasts: weatherService.weeklyForecast,
                       isLoading: weatherService.isLoadingForecast
                   )
                   .padding(.horizontal)
                   .cardEnterAnimation(delay: 0.5)
            .onAppear {
                // Trigger weekly forecast fetch when card appears (lazy loading)
                if shouldLoadWeeklyData && weatherService.weeklyForecast.isEmpty && !weatherService.isLoadingForecast {
                    Task {
                        if let location = getEffectiveLocation() {
                            print("🔄 HomeView: Lazy loading weekly forecast...")
                            await weatherService.fetchWeeklyForecast(for: location)
                            // After weekly forecast loads, trigger weekly insight analysis WITH weekly forecast
                            if !weatherService.weeklyForecast.isEmpty {
                                print("🔄 HomeView: Weekly forecast loaded, triggering weekly insight analysis...")
                                await refreshAnalysis(force: true, includeWeeklyForecast: true)
                            }
                        }
                    }
                }
            }
            
            // Apple Weather Attribution (required by App Store Guideline 5.2.5)
            AppleWeatherAttributionView()
                .padding(.horizontal)
                .padding(.top, 8)
                .cardEnterAnimation(delay: 0.6)
        }
        .padding(.vertical)
    }
    
    private var aiInsightsCard: some View {
        DailyInsightCardView(
            title: "Daily AI Insight",
            subtitle: authManager.isAuthenticated ? "Today's Health Analysis" : "General Weather Insights",
            icon: "lightbulb.fill",
            message: aiService.insightMessage.isEmpty ? "Analyzing weather patterns…" : aiService.insightMessage,
            supportNote: authManager.isAuthenticated ? aiService.supportNote : nil, // Only show support note when authenticated
            personalAnecdote: authManager.isAuthenticated ? aiService.personalAnecdote : nil, // Only show personal anecdote when authenticated
            behaviorPrompt: authManager.isAuthenticated ? aiService.behaviorPrompt : nil, // Only show behavior prompt when authenticated
            citations: aiService.citations,
            disclaimerText: "Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.",
            // Only show loading spinner if we don't have any insights yet (first load)
            // If we have cached insights, show them and update in background without blocking UI
            isLoading: aiService.isLoading && !aiService.hasValidInsights,
            isRefreshing: isManualInsightRefresh,
            showRefreshButton: true,
            showFeedbackPrompt: authManager.isAuthenticated, // Only show feedback prompt when authenticated
            onRefresh: {
                guard !isManualInsightRefresh else { return }
                isManualInsightRefresh = true
                Task {
                    print("🔄 Manual insight refresh triggered from card button")
                    // Manual refresh should bypass all caches and get fresh data
                    // Include weekly forecast for complete refresh
                    await refreshAnalysis(force: true, includeWeeklyForecast: true)
                    await MainActor.run {
                        isManualInsightRefresh = false
                    }
                }
            },
            feedbackBinding: $aiFeedback,
            submitFeedback: { choice in
                if let choice = choice {
                    print("AI Feedback: \(choice ? "Helpful" : "Not Helpful")")
                    Task {
                        await aiService.submitFeedback(isHelpful: choice)
                    }
                } else {
                    print("AI Feedback: Cleared")
                }
            }
        )
        .padding(.horizontal)
        .overlay(alignment: .bottomTrailing) {
            // Show a subtle badge when not authenticated
            if !authManager.isAuthenticated && !aiService.insightMessage.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Sign up for personalized insights")
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.adaptiveCardBackground.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            baseScrollView
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        LogoWordmarkView()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
                .refreshable {
                    await handleRefresh()
                }
                .modifier(LocationChangeModifier(
                    locationManager: locationManager,
                    weatherService: weatherService,
                    aiService: aiService,
                    scenePhase: scenePhase,
                    authManager: authManager,
                    handleViewAppearAction: handleViewAppearAction,
                    handleLocationChange: handleLocationChange,
                    handleLocationPreferenceChange: handleLocationPreferenceChange,
                    handleWeatherDataChange: handleWeatherDataChangeWithCheck,
                    handleAuthorizationStatusChange: handleAuthorizationStatusChange,
                    handleScenePhaseChange: handleScenePhaseChange,
                    hasInitialAnalysis: hasInitialAnalysis,
                    hasGeneratedDailyInsightSession: hasGeneratedDailyInsightSession,
                    lastDiagnosesHash: lastDiagnosesHash,
                    handleUserProfileChange: handleUserProfileChange,
                    checkAccessStatus: checkAccessStatus,
                    refreshUserInfoAndCheckAccess: refreshUserInfoAndCheckAccess,
                    aiFeedback: $aiFeedback,
                    showingOnboarding: $showingOnboarding,
                    showingPaywall: $showingPaywall,
                    showingAccessExpiredPopup: $showingAccessExpiredPopup,
                    subscriptionManager: subscriptionManager
                ))
        }
    }
    
    private var baseScrollView: some View {
        ZStack {
            scrollViewContent
                .background(backgroundView)
            
            loadingOverlay
        }
    }
    
    private func checkAccessStatus() {
        if let user = authManager.currentUser, user.access_required == true {
            showingAccessExpiredPopup = true
        }
    }
    
    private func handleRefresh() async {
        print("🔄 Manual refresh triggered - bypassing all caches")
        
        // Manual refresh should bypass all optimizations and get fresh data
        if let location = getEffectiveLocation() {
            // Force refresh weather data
            await weatherService.refreshWeatherData(for: location)
            // Fetch all forecasts (user explicitly wants fresh data)
            await weatherService.fetchHourlyForecast(for: location)
            await weatherService.fetchWeeklyForecast(for: location)
        }
        
        // Force refresh analysis with all data (bypasses time-based caching and input hash checks)
        // This ensures user gets completely fresh insights when they manually refresh
        await refreshAnalysis(force: true, includeWeeklyForecast: true)
        
        // Ensure weekly data is enabled after refresh
        await MainActor.run {
            shouldLoadWeeklyData = true
        }
        
        print("✅ Manual refresh complete")
    }
    
    private var scrollViewContent: some View {
        ScrollView {
            contentView
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if aiService.isLoading && !aiService.hasValidInsights {
            LoadingOverlayView()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: aiService.isLoading)
        }
    }
    
    private func handleViewAppearAction() {
        // Check if aiService already has valid insights (persists across navigation)
        let hasExistingInsights = (aiService.insightMessage != "Analyzing your week…" && 
                                  aiService.insightMessage != "Analyzing weather patterns…" && 
                                  aiService.insightMessage != "Updating analysis…" && 
                                  !aiService.insightMessage.isEmpty) ||
                                 (aiService.weeklyInsightSummary != nil && !aiService.weeklyInsightSummary!.isEmpty) ||
                                 (aiService.risk != nil)
        
        // Sync the state flags - if we have existing insights, restore the flags
        if hasExistingInsights {
            hasInitialAnalysis = true
            hasGeneratedDailyInsightSession = true
            shouldLoadWeeklyData = true // Enable weekly data loading if we already have insights
            print("✅ HomeView: Found existing insights, restored flags")
        } else {
            hasInitialAnalysis = hasGeneratedDailyInsightSession
        }
        
        print("🏠 HomeView: View appeared")
        print("🧠 HomeView: hasInitialAnalysis: \(hasInitialAnalysis)")
        print("🧠 HomeView: hasGeneratedDailyInsightSession: \(hasGeneratedDailyInsightSession)")
        print("🧠 HomeView: hasExistingInsights: \(hasExistingInsights)")
        
        handleViewAppear()
        
        // Don't trigger analysis here - let handleWeatherDataChange do it when weather arrives
        // This prevents duplicate calls and ensures analysis only starts when weather is ready
        if hasGeneratedDailyInsightSession || hasExistingInsights {
            print("⏭️ HomeView: Already have initial analysis or existing insights, skipping onAppear refresh")
        } else {
            print("🔄 HomeView: Will trigger analysis when weather data arrives")
        }
    }
    
    private func handleWeatherDataChangeWithCheck(old: WeatherData?, new: WeatherData?) {
        // Check if we have existing insights (persists across navigation)
        let hasExistingInsights = (aiService.insightMessage != "Analyzing your week…" && 
                                  aiService.insightMessage != "Analyzing weather patterns…" && 
                                  aiService.insightMessage != "Updating analysis…" && 
                                  !aiService.insightMessage.isEmpty) ||
                                 (aiService.weeklyInsightSummary != nil && !aiService.weeklyInsightSummary!.isEmpty) ||
                                 (aiService.risk != nil)
        
        // STRICT: Don't process at all if we already have analysis or existing insights (prevents retrigger on navigation)
        if hasInitialAnalysis || hasGeneratedDailyInsightSession || hasExistingInsights {
            if hasExistingInsights {
                // Sync flags if we have existing insights
                hasInitialAnalysis = true
                hasGeneratedDailyInsightSession = true
            }
            print("⏭️ HomeView: Already have analysis or existing insights, skipping weather change check completely")
            return
        }
        
        // Only process if values actually changed in a noteworthy way
        if weatherDataValuesChanged(old: old, new: new) {
            print("🌤️ HomeView: Weather data values actually changed (noteworthy change)")
            handleWeatherDataChange(new)
        } else if new != nil && old == nil {
            // First time we get weather data - start analysis immediately
            print("🌤️ HomeView: Weather data available for first time, starting analysis...")
            handleWeatherDataChange(new)
        } else {
            // Values didn't change and we already had data - skip
            print("⏭️ HomeView: Weather data instance changed but values are the same, skipping")
        }
    }
    
    // Handle user profile changes (diagnoses or sensitivities)
    private func handleUserProfileChange() {
        let currentHash = getUserProfileHash()
        
        // Skip on first check (when lastDiagnosesHash is nil) - this is just initialization
        guard let lastHash = lastDiagnosesHash else {
            lastDiagnosesHash = currentHash
            lastSensitivitiesHash = currentHash
            return
        }
        
        // Only trigger if profile actually changed
        if currentHash != lastHash {
            print("🔄 HomeView: User profile changed (diagnoses or sensitivities), refreshing analysis...")
            print("   Old hash: \(lastHash)")
            print("   New hash: \(currentHash)")
            lastDiagnosesHash = currentHash
            lastSensitivitiesHash = currentHash
            
            Task {
                // Profile change should include weekly forecast for complete refresh
                await refreshAnalysis(force: true, includeWeeklyForecast: true)
            }
        } else {
            print("⏭️ HomeView: User profile unchanged, skipping refresh")
        }
    }
}

// Prominent loading overlay for insights processing
private struct LoadingOverlayView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Loading card
            VStack(spacing: 20) {
                // Animated weather icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#888779").opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#888779"))
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(scale)
                }
                
                // Loading text
                VStack(spacing: 8) {
                    Text("Analyzing Weather Patterns")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("This will just take a moment...")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                }
                
                // Progress indicator
                ProgressView()
                    .tint(Color(hex: "#888779"))
                    .scaleEffect(1.2)
            }
            .padding(32)
            .background(Color.adaptiveBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Animate rotation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Animate scale pulse
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
        }
    }
}

private struct LogoWordmarkView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("AppLogo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(height: 24)
                .foregroundColor(Color.adaptiveText)
            Text("FlareWeather")
                .font(.interHeadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FlareWeather")
    }
}

struct DailyInsightCardView: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let subtitle: String
    let icon: String
    let message: String
    let supportNote: String?
    let personalAnecdote: String?
    let behaviorPrompt: String?
    let citations: [String]
    let disclaimerText: String
    let isLoading: Bool
    let isRefreshing: Bool
    let showRefreshButton: Bool
    let showFeedbackPrompt: Bool
    var onRefresh: (() -> Void)?
    var feedbackBinding: Binding<Bool?>?
    var submitFeedback: ((Bool?) -> Void)?
    
    // Parse the formatted daily message into summary / why / comfort / sign-off sections.
    private var parsedSections: (summary: String, why: String?, comfort: String?, signOff: String?) {
        let normalized = message.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !blocks.isEmpty else {
            return ("", nil, nil, nil)
        }
        
        // Get summary and filter out "☀️ Daily Insight" header
        var summary = blocks.first ?? ""
        
        // Remove "☀️ Daily Insight" header from summary (card title already has it)
        let headerPatterns = [
            "(?i)☀️\\s*Daily\\s+Insight\\s*:?\\s*",
            "(?i)☀\\s*Daily\\s+Insight\\s*:?\\s*",
            "(?i)Daily\\s+Insight\\s*:?\\s*",
            "(?i)^☀️\\s*",
            "(?i)^☀\\s*"
        ]
        
        for pattern in headerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(summary.startIndex..., in: summary)
                summary = regex.stringByReplacingMatches(in: summary, options: [], range: range, withTemplate: "")
            }
        }
        
        summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If summary is now empty or just whitespace after removing header, use next block
        // Also check if summary is ONLY the header (no actual content)
        if summary.isEmpty || summary.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "daily insight" {
            if blocks.count > 1 {
                summary = blocks[1]
                // Also filter header from this block just in case
                for pattern in headerPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let range = NSRange(summary.startIndex..., in: summary)
                        summary = regex.stringByReplacingMatches(in: summary, options: [], range: range, withTemplate: "")
                    }
                }
                summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // Fallback if no other blocks
                summary = ""
            }
        }
        
        var why: String?
        var comfort: String?
        var signOff: String?
        
        // Process remaining blocks (skip summary)
        // If we used blocks[0] as summary and it was empty/just header, we may have used blocks[1] as summary
        // So we need to figure out which blocks to skip
        let blocksToProcess: [String]
        if blocks.count > 0 && (blocks.first?.lowercased().contains("daily insight") ?? false || summary == blocks.first || summary.isEmpty) {
            // If first block was header or we used blocks[1] as summary
            if summary.isEmpty && blocks.count > 1 {
                // We used blocks[1] as summary, so skip blocks[0] and blocks[1]
                blocksToProcess = Array(blocks.dropFirst(2))
            } else {
                // Normal case: first block is summary (after filtering header)
                blocksToProcess = Array(blocks.dropFirst())
            }
        } else {
            // First block wasn't header, process from block 1
            blocksToProcess = Array(blocks.dropFirst())
        }
        
        for block in blocksToProcess {
            if block.hasPrefix("Why:") {
                let trimmed = block.dropFirst("Why:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && why == nil {
                    why = trimmed
                }
            } else if block.hasPrefix("Comfort tip:") {
                // Only take the FIRST comfort tip, ignore duplicates
                if comfort == nil {
                    let trimmed = block.dropFirst("Comfort tip:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        comfort = trimmed
                    }
                }
            } else {
                // Sign-off is the last non-prefixed block (but not if it's a duplicate of comfort)
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && signOff == nil {
                    signOff = trimmed
                }
            }
        }
        
        // Prevent duplicate: if sign-off matches summary, comfort tip, or why, remove it
        let summaryClean = summary.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
        
        if let signOff = signOff {
            let signOffClean = signOff.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            
            // Check if sign-off is the same as summary (common duplicate)
            if !summaryClean.isEmpty && signOffClean == summaryClean {
                return (summary, why, comfort, nil)
            }
            
            // Check if sign-off contains summary or vice versa
            if !summaryClean.isEmpty {
                if signOffClean.contains(summaryClean) || summaryClean.contains(signOffClean) {
                    let shorter = min(summaryClean.count, signOffClean.count)
                    if shorter > 0 {
                        let matchLength = signOffClean.contains(summaryClean) ? summaryClean.count : signOffClean.count
                        if Double(matchLength) / Double(shorter) > 0.8 {
                            return (summary, why, comfort, nil)
                        }
                    }
                }
            }
            
            // Check if sign-off is the same as comfort tip
            if let comfort = comfort {
                let comfortClean = comfort.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                
                if comfortClean == signOffClean {
                    return (summary, why, comfort, nil)
                }
                
                // Also check if one contains the other (for partial matches)
                let shorter = min(comfortClean.count, signOffClean.count)
                if shorter > 0 {
                    if comfortClean.contains(signOffClean) || signOffClean.contains(comfortClean) {
                        let matchLength = comfortClean.contains(signOffClean) ? signOffClean.count : comfortClean.count
                        if Double(matchLength) / Double(shorter) > 0.8 {
                            return (summary, why, comfort, nil)
                        }
                    }
                }
            }
            
            // Check if sign-off is the same as why
            if let why = why {
                let whyClean = why.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                
                if whyClean == signOffClean {
                    return (summary, why, comfort, nil)
                }
            }
        }
        
        return (summary, why, comfort, signOff)
    }
    
    var body: some View {
        let sections = parsedSections
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.interHeadline)
                        .foregroundColor(Color.adaptiveText)
                    Text(subtitle)
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                }
                
                Spacer()
                
                if showRefreshButton {
                    if isLoading || isRefreshing {
                        ProgressView()
                            .tint(Color.adaptiveText)
                            .scaleEffect(0.8)
                            .transition(.opacity.combined(with: .scale))
                    } else if let onRefresh = onRefresh {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh Insight")
                    }
                }
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .tint(Color.adaptiveText)
                        .scaleEffect(0.8)
                    Text("Analyzing weather patterns…")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Summary paragraph
                    if !sections.summary.isEmpty {
                        Text(sections.summary)
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    if sections.why != nil || sections.comfort != nil {
                        Divider()
                            .background(Color.adaptiveMuted.opacity(0.2))
                    }
                    
                    // Why row with info icon
                    if let why = sections.why, !why.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.interBody)
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#888779"))
                            Text("Why: \(why)")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // Comfort tip row with hand icon
                    if let comfort = sections.comfort, !comfort.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "hands.sparkles.fill")
                                .font(.interBody)
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#888779"))
                            Text("Comfort tip: \(comfort)")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // Sign-off removed per user request - no longer displayed
                    
                    // Don't show supportNote if there's already a comfort tip (prevents duplicate comfort tips)
                    // Only show supportNote if there's no comfort tip from the parsed sections
                    if sections.comfort == nil || sections.comfort?.isEmpty == true {
                        if let supportNote = supportNote, !supportNote.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Divider()
                                    .background(Color.adaptiveMuted.opacity(0.2))
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "hands.sparkles.fill")
                                        .font(.interCaption)
                                        .foregroundColor(Color.adaptiveText)
                                    Text(supportNote)
                                        .font(.interCaption)
                                        .foregroundColor(Color.adaptiveText)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.adaptiveCardBackground.opacity(0.45))
                                .cornerRadius(14)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    
                    if let personalAnecdote = personalAnecdote, !personalAnecdote.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider()
                                .background(Color.adaptiveMuted.opacity(0.15))
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "quote.bubble")
                                    .font(.interCaption)
                                    .foregroundColor(Color.adaptiveMuted)
                                Text(personalAnecdote)
                                    .font(.interCaption)
                                    .foregroundColor(Color.adaptiveMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    if let behaviorPrompt = behaviorPrompt, !behaviorPrompt.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider()
                                .background(Color.adaptiveMuted.opacity(0.15))
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                    .font(.interCaption)
                                    .foregroundColor(Color.adaptiveText)
                                Text(behaviorPrompt)
                                    .font(.interCaption)
                                    .foregroundColor(Color.adaptiveText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    Text(disclaimerText)
                        .font(.interSmall)
                        .foregroundColor(Color.adaptiveMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    
                    if showFeedbackPrompt,
                       let binding = feedbackBinding,
                       let submitFeedback = submitFeedback {
                        FeedbackPromptView(aiFeedback: binding, submitAction: submitFeedback)
                    }
                }
            }
            
            if !citations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.adaptiveMuted.opacity(0.3))
                    
                    HStack(spacing: 4) {
                        Text("Sources")
                            .font(.interCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.adaptiveMuted)
                        
                        if citations.count > 1 {
                            Text("(\(citations.count) peer-reviewed studies)")
                                .font(.interCaption)
                                .foregroundColor(Color.adaptiveMuted.opacity(0.8))
                        } else {
                            Text("(peer-reviewed research)")
                                .font(.interCaption)
                                .foregroundColor(Color.adaptiveMuted.opacity(0.8))
                        }
                    }
                    
                    ForEach(citations, id: \.self) { citation in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.interCaption)
                                .foregroundColor(Color.adaptiveMuted)
                            Text(citation)
                                .font(.interSmall)
                                .foregroundColor(Color.adaptiveMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .cardStyle()
    }
}

struct FeedbackPromptView: View {
    @Binding var aiFeedback: Bool?
    var submitAction: (Bool?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.adaptiveMuted.opacity(0.2))
            
            Text("Was this helpful?")
                .font(.interCaption)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveMuted)
            
            HStack(spacing: 12) {
                feedbackButton(isPositive: true, label: "Yes", icon: "hand.thumbsup.fill")
                feedbackButton(isPositive: false, label: "No", icon: "hand.thumbsdown.fill")
            }
        }
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.2), value: aiFeedback)
    }
    
    private func feedbackButton(isPositive: Bool, label: String, icon: String) -> some View {
        let isSelected = aiFeedback == isPositive
        return Button {
            if aiFeedback == isPositive {
                aiFeedback = nil
                submitAction(nil)
            } else {
                aiFeedback = isPositive
                submitAction(isPositive)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.interCaption.weight(.semibold))
                Text(label)
                    .font(.interCaption)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(isSelected ? Color.adaptiveCardBackground.opacity(0.35) : Color.clear)
            .foregroundColor(Color.adaptiveText)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.adaptiveCardBackground : Color.adaptiveMuted.opacity(0.4), lineWidth: 1.5)
            )
            .cornerRadius(12)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct WeatherCardView: View {
    let weatherData: WeatherData?
    let isLoading: Bool
    let errorMessage: String?
    let locationName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                        .font(.title)
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("Current Weather")
                        .font(.interHeadline)
                        .foregroundColor(Color.adaptiveText)
                    
                    Spacer()
                }
                
                if let locationName = locationName, !locationName.isEmpty {
                    Text(locationName)
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.leading, 32) // Align with text below icon
                }
            }
            
                    if let weather = weatherData {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                let temp = weather.temperature.isNaN || weather.temperature.isInfinite ? 0 : weather.temperature
                                let displayTemp = temp.toTemperature()
                                let unit = temp.temperatureUnit
                                Text("\(Int(displayTemp))°")
                                    .font(.system(size: 64, weight: .light))
                                    .foregroundColor(Color.adaptiveText)
                                    .contentTransition(.numericText())
                                
                                Text(unit)
                                    .font(.title2)
                                    .foregroundColor(Color.adaptiveMuted)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(weather.condition)
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveText)
                                        .fontWeight(.medium)
                                    
                                    Text("Feels like \(Int(displayTemp))°")
                                        .font(.interCaption)
                                        .foregroundColor(Color.adaptiveMuted)
                                        .contentTransition(.numericText())
                                }
                            }
                            .animation(.easeInOut(duration: 0.4), value: weather.temperature)
                    
                    Divider()
                        .background(Color.adaptiveMuted.opacity(0.3))
                    
                            HStack(spacing: 20) {
                                let humidity = weather.humidity.isNaN || weather.humidity.isInfinite ? 0 : weather.humidity
                                let windSpeed = weather.windSpeed.isNaN || weather.windSpeed.isInfinite ? 0 : weather.windSpeed
                                let pressure = weather.pressure.isNaN || weather.pressure.isInfinite ? 0 : weather.pressure
                                
                                WeatherDetailView(icon: "humidity", value: "\(Int(humidity))%", label: "Humidity")
                                WeatherDetailView(icon: "wind", value: "\(Int(windSpeed))", label: "km/h")
                                WeatherDetailView(icon: "barometer", value: "\(Int(pressure))", label: "Pressure (hPa)")
                                
                                // Air Quality - show beside pressure if available
                                if let aqi = weather.airQuality {
                                    WeatherDetailView(icon: "air.purifier", value: airQualityLabel(for: aqi), label: "Air Quality")
                                }
                            }
                            .animation(.easeOut(duration: 0.3), value: weather)
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        ProgressView()
                            .tint(Color.adaptiveText)
                        Text(isLoading ? "Loading weather..." : "No weather data")
                            .foregroundColor(Color.adaptiveMuted)
                            .font(.interBody)
                            .padding(.leading, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.interCaption)
                            .foregroundColor(Color.adaptiveMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct PressureAlertCardView: View {
    let alert: PressureAlertPayload
    @Environment(\.colorScheme) private var colorScheme
    
    private var alertTitle: String {
        switch alert.alertLevel.lowercased() {
        case "high":
            return "Pressure Shift Incoming"
        case "moderate":
            return "Pressure Change Ahead"
        default:
            return "Pressure Wiggle Ahead"
        }
    }
    
    private var accentColor: Color {
        switch alert.alertLevel.lowercased() {
        case "high":
            return colorScheme == .dark ? Color(hex: "#FF6B6B") : Color(hex: "#8B1A1A")
        case "moderate":
            return colorScheme == .dark ? Color(hex: "#FFB84D") : Color(hex: "#B8681A")
        default:
            return colorScheme == .dark ? Color(hex: "#4ECDC4") : Color(hex: "#1A6B5A")
        }
    }
    
    private var triggerTimeDescription: String {
        guard let date = alert.triggerDate else { return "Soon" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "barometer")
                    .font(.title3)
                    .foregroundColor(accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alertTitle)
                        .font(.interHeadline)
                        .foregroundColor(Color.adaptiveText)
                    Text("Δ \(String(format: "%.1f", alert.pressureDelta)) hPa by \(triggerTimeDescription)")
                        .font(.interCaption)
                        .foregroundColor(accentColor)
                }
                Spacer()
            }
            
            Text(alert.suggestedMessage)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }
}

struct WeatherDetailView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.interCaption)
                .foregroundColor(Color.adaptiveMuted)
            Text(value)
                .font(.interBody)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptiveText)
                .contentTransition(.numericText())
            Text(label)
                .font(.interSmall)
                .foregroundColor(Color.adaptiveMuted)
        }
    }
}

// Helper function to format air quality label
private func airQualityLabel(for aqi: Int) -> String {
    switch aqi {
    case 1:
        return "Good"
    case 2:
        return "Fair"
    case 3:
        return "Moderate"
    case 4:
        return "Poor"
    case 5:
        return "Very Poor"
    default:
        return "Unknown"
    }
}

struct WeeklyForecastCardView: View {
    let forecasts: [DailyForecast]
    let isLoading: Bool
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // Day of week (Mon, Tue, etc.)
        return formatter
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // Month and day
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                Text("7-Day Forecast")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(Color.adaptiveText)
                        .scaleEffect(0.8)
                }
            }
            
            if forecasts.isEmpty && !isLoading {
                Text("Forecast data will appear here")
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !forecasts.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(forecasts) { forecast in
                                ForecastDayRow(forecast: forecast, dateFormatter: dateFormatter, dayFormatter: dayFormatter)
                            }
                        }
                        .animation(.easeOut(duration: 0.3), value: forecasts.count)
                    }
        }
        .cardStyle()
    }
}

struct ForecastDayRow: View {
    let forecast: DailyForecast
    let dateFormatter: DateFormatter
    let dayFormatter: DateFormatter
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(forecast.date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Day label
            VStack(alignment: .leading, spacing: 2) {
                if isToday {
                    Text("Today")
                        .font(.interBody)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText)
                } else {
                    Text(dateFormatter.string(from: forecast.date))
                        .font(.interBody)
                        .fontWeight(.medium)
                        .foregroundColor(Color.adaptiveText)
                    Text(dayFormatter.string(from: forecast.date))
                        .font(.interSmall)
                        .foregroundColor(Color.adaptiveMuted)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // Weather icon
            Image(systemName: weatherIcon(for: forecast.icon))
                .font(.title3)
                .foregroundColor(Color.adaptiveText)
                .frame(width: 30)
            
            // Condition
            Text(forecast.condition)
                .font(.interCaption)
                .foregroundColor(Color.adaptiveMuted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
                    // Temperature range
                    HStack(spacing: 8) {
                        Text("\(Int(forecast.highTemp.toTemperature()))°")
                            .font(.interBody)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.adaptiveText)
                            .contentTransition(.numericText())
                        Text("\(Int(forecast.lowTemp.toTemperature()))°")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                            .contentTransition(.numericText())
                    }
                    .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func weatherIcon(for iconCode: String) -> String {
        // If iconCode is already an SF Symbol (from WeatherKit), return it as-is
        // SF Symbols contain dots (e.g., "sun.max.fill"), OpenWeatherMap codes don't
        if iconCode.contains(".") {
            return iconCode // Already an SF Symbol from WeatherKit
        }
        
        // Map OpenWeatherMap icon codes to SF Symbols (for backward compatibility)
        switch iconCode {
        case "01d", "01n": return "sun.max.fill" // Clear sky
        case "02d", "02n": return "cloud.sun.fill" // Few clouds
        case "03d", "03n": return "cloud.fill" // Scattered clouds
        case "04d", "04n": return "cloud.fill" // Broken clouds
        case "09d", "09n": return "cloud.rain.fill" // Shower rain
        case "10d", "10n": return "cloud.sun.rain.fill" // Rain
        case "11d", "11n": return "cloud.bolt.fill" // Thunderstorm
        case "13d", "13n": return "cloud.snow.fill" // Snow
        case "50d", "50n": return "cloud.fog.fill" // Mist
        default: return "cloud.fill"
        }
    }
}


struct FlareRiskCardView: View {
    let risk: String?
    let forecast: String?
    let isLoading: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var riskColor: Color {
        guard let risk = risk else { return Color.adaptiveMuted }
        
        // Use brighter colors in dark mode for better contrast
        let isDarkMode = colorScheme == .dark
        
        switch risk.uppercased() {
        case "HIGH":
            // Light red/orange in dark mode, deep burgundy in light mode
            return isDarkMode ? Color(hex: "#FF6B6B") : Color(hex: "#8B1A1A")
        case "MODERATE":
            // Brighter amber/yellow in dark mode for visibility, deep rust in light mode
            return isDarkMode ? Color(hex: "#FFA500") : Color(hex: "#B8681A")
        case "LOW":
            // Light teal/green in dark mode, deep teal in light mode
            return isDarkMode ? Color(hex: "#4ECDC4") : Color(hex: "#1A6B5A")
        default:
            return Color.adaptiveMuted
        }
    }
    
    private var riskIcon: String {
        guard let risk = risk else { return "questionmark.circle" }
        switch risk.uppercased() {
        case "HIGH":
            return "exclamationmark.triangle.fill"
        case "MODERATE":
            return "exclamationmark.circle.fill"
        case "LOW":
            return "checkmark.circle.fill"
        default:
            return "questionmark.circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                Text("Flare Risk")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(Color.adaptiveText)
                        .scaleEffect(0.8)
                        .transition(.opacity.combined(with: .scale))
                } else if let risk = risk {
                    HStack(spacing: 8) {
                        Image(systemName: riskIcon)
                            .font(.interBody)
                            .foregroundColor(riskColor)
                        Text(risk.uppercased())
                            .font(.interBody)
                            .fontWeight(.semibold)
                            .foregroundColor(riskColor)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(minWidth: 120)
                    .background(riskColor.opacity(0.2))
                    .cornerRadius(10)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: risk)
                } else {
                    // Show loading state when no risk data yet
                    ProgressView()
                        .tint(Color.adaptiveText)
                        .scaleEffect(0.8)
                }
            }
        }
        .cardStyle()
    }
}

struct HourlyForecastCardView: View {
    let forecasts: [HourlyForecast]
    let isLoading: Bool
    let currentPressure: Double? // Current weather pressure to use as baseline for first forecast
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha" // e.g., "2PM", "8AM"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                Text("24-Hour Forecast")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(Color.adaptiveText)
                        .scaleEffect(0.8)
                }
            }
            
            if forecasts.isEmpty && !isLoading {
                Text("Hourly forecast data will appear here")
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !forecasts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(forecasts.prefix(24).enumerated()), id: \.element.id) { index, forecast in
                            // Use current weather pressure as baseline for first forecast item
                            // Otherwise use previous forecast's pressure
                            let previousPressure = index > 0 
                                ? forecasts[index - 1].pressure 
                                : (currentPressure ?? forecast.pressure)
                            HourlyForecastRow(
                                forecast: forecast,
                                previousPressure: previousPressure,
                                timeFormatter: timeFormatter
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .animation(.easeOut(duration: 0.3), value: forecasts.count)
                
                Text("Arrows flag hours where pressure trends sharply. Up arrows hint at relief periods. Down arrows suggest moment to pace gently.")
                    .font(.interCaption)
                    .italic()
                    .foregroundColor(Color.adaptiveMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .cardStyle()
    }
}

struct HourlyForecastRow: View {
    let forecast: HourlyForecast
    let previousPressure: Double
    let timeFormatter: DateFormatter
    
    private var isCurrentHour: Bool {
        Calendar.current.isDate(forecast.time, equalTo: Date(), toGranularity: .hour)
    }
    
    // Calculate pressure change from previous hour
    private var pressureChange: Double {
        forecast.pressure - previousPressure
    }
    
    // Determine if pressure change is significant
    private var hasSignificantPressureChange: Bool {
        abs(pressureChange) >= 0.5
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Time
            Text(isCurrentHour ? "Now" : timeFormatter.string(from: forecast.time).lowercased())
                .font(.interSmall)
                .fontWeight(isCurrentHour ? .semibold : .regular)
                .foregroundColor(isCurrentHour ? Color.adaptiveText : Color.adaptiveMuted)
            
            // Weather icon
            Image(systemName: weatherIcon(for: forecast.icon))
                .font(.title3)
                .foregroundColor(Color.adaptiveText)
                .frame(height: 24)
            
            // Temperature
            Text("\(Int(forecast.temperature.toTemperature()))°")
                .font(.interBody)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptiveText)
                .contentTransition(.numericText())
            
            // Pressure change indicator (if significant change)
            if hasSignificantPressureChange {
                if pressureChange < 0 {
                    // Pressure dropping
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#8B1A1A"))
                        .frame(width: 16, height: 16)
                } else {
                    // Pressure rising
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#1A6B5A"))
                        .frame(width: 16, height: 16)
                }
            } else {
                Color.clear
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: 60)
        .padding(.vertical, 8)
    }
    
    private func weatherIcon(for iconCode: String) -> String {
        // If iconCode is already an SF Symbol (from WeatherKit), return it as-is
        // SF Symbols contain dots (e.g., "sun.max.fill"), OpenWeatherMap codes don't
        if iconCode.contains(".") {
            return iconCode // Already an SF Symbol from WeatherKit
        }
        
        // Map OpenWeatherMap icon codes to SF Symbols (for backward compatibility)
        switch iconCode {
        case "01d", "01n": return "sun.max.fill" // Clear sky
        case "02d", "02n": return "cloud.sun.fill" // Few clouds
        case "03d", "03n": return "cloud.fill" // Scattered clouds
        case "04d", "04n": return "cloud.fill" // Broken clouds
        case "09d", "09n": return "cloud.rain.fill" // Shower rain
        case "10d", "10n": return "cloud.sun.rain.fill" // Rain
        case "11d", "11n": return "cloud.bolt.fill" // Thunderstorm
        case "13d", "13n": return "cloud.snow.fill" // Snow
        case "50d", "50n": return "cloud.fog.fill" // Mist
        default: return "cloud.fill"
        }
    }
}

struct WeeklyForecastInsightCardView: View {
    @Environment(\.colorScheme) var colorScheme
    let summary: String
    let days: [WeeklyInsightDay]
    let sources: [String]
    
    // Helper to format weekday labels (add period for shorter days)
    private func formatWeekdayLabel(_ label: String) -> String {
        let lowercased = label.lowercased()
        if lowercased == "mon" || lowercased == "tue" || lowercased == "wed" || lowercased == "thu" || lowercased == "fri" || lowercased == "sat" || lowercased == "sun" {
            // Capitalize first letter and add period
            return label.prefix(1).uppercased() + label.dropFirst().lowercased() + "."
        }
        // Already formatted or longer name
        return label
    }
    
    // Helper to extract risk level from detail text (Low, Moderate, High)
    private func extractRiskLevel(_ detail: String) -> String {
        let lowerDetail = detail.lowercased()
        
        // Check for explicit risk indicators
        if lowerDetail.contains("high") || lowerDetail.contains("elevated") || lowerDetail.contains("severe") || lowerDetail.contains("sharp") {
            return "High"
        } else if lowerDetail.contains("moderate") || lowerDetail.contains("moderate risk") {
            return "Moderate"
        } else if lowerDetail.contains("low") || lowerDetail.contains("steady") || lowerDetail.contains("calm") || lowerDetail.contains("gentle") || lowerDetail.contains("mild") || lowerDetail.contains("stable") {
            return "Low"
        }
        
        // Default to Low if no clear indicator
        return "Low"
    }
    
    // Helper to remove risk level from detail text (to avoid duplication)
    // New format: "Low flare risk — steady pressure" -> "steady pressure"
    // IMPORTANT: Preserve the FULL descriptor text - do not truncate
    private func removeRiskLevelFromDetail(_ detail: String) -> String {
        var cleaned = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it follows the new format: "Risk Level — descriptor"
        // Try all dash types: em-dash (—), en-dash (–), regular dash (-)
        let dashPatterns = [" — ", " – ", " - ", "—", "–", "-"]
        
        for dashPattern in dashPatterns {
            if let dashRange = cleaned.range(of: dashPattern) {
                // Format: "Low flare risk — steady pressure"
                let beforeDash = String(cleaned[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let afterDash = String(cleaned[dashRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if before dash contains risk level keywords
                let beforeLower = beforeDash.lowercased()
                if beforeLower.contains("low") || beforeLower.contains("moderate") || beforeLower.contains("high") || beforeLower.contains("risk") {
                    // This is the new format - return the descriptor after the dash
                    if !afterDash.isEmpty {
                        return afterDash
                    }
                }
            }
        }
        
        // Also try regex pattern to catch variations in spacing
        // Match: "Low flare risk" or "Moderate risk" or "High risk" followed by dash and descriptor
        let dashRegexPattern = #"(?i)(low\s+flare\s+risk|moderate\s+risk|high\s+risk)\s*[—–-]\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: dashRegexPattern, options: []),
           let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count)),
           match.numberOfRanges > 2 {
            let descriptorRange = match.range(at: 2)
            if descriptorRange.location != NSNotFound {
                let descriptor = (cleaned as NSString).substring(with: descriptorRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !descriptor.isEmpty {
                    return descriptor
                }
            }
        }
        
        // Fallback: Remove explicit risk phrases but preserve descriptor content
        let riskPhrases = [
            "low flare risk",
            "low risk",
            "moderate risk",
            "high risk",
            "elevated risk",
            "generally low flare risk",
            "often low flare risk",
            "typically low flare risk"
        ]
        
        for phrase in riskPhrases {
            // Remove phrase at the start followed by dash or space
            let pattern = "^\(phrase)\\s*[—–-]?\\s*"
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Remove standalone "Low" at the start (but preserve "low pressure", "low humidity", etc.)
        cleaned = cleaned.replacingOccurrences(
            of: "^[Ll]ow\\s+(?!pressure|humidity|temperature|wind|flare)",
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean up any double spaces
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If we have a meaningful descriptor, return it; otherwise return a default
        if cleaned.isEmpty || cleaned.lowercased() == "low" || cleaned.lowercased() == "flare risk" {
            // No descriptor found - this shouldn't happen, but return empty so UI shows just the risk badge
            return ""
        }
        
        return cleaned
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: "Weekly Insight" (matching design)
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                Text("Weekly Insight")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
            }
            
            // Weekly summary: one paragraph, no bullets, left-aligned
            // Add line breaks between paragraphs if summary contains multiple paragraphs
            if summary.isEmpty {
                Text("Preparing your weekly insight…")
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Split summary by double newlines to detect paragraphs
                let paragraphs = summary.components(separatedBy: "\n\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                if paragraphs.count > 1 {
                    // Multiple paragraphs - render with spacing
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                    }
                } else {
                    // Single paragraph
                    Text(summary)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveText)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Daily breakdown: weekday label (bold) followed by detail text (regular, lighter)
            if !days.isEmpty {
                Divider()
                    .background(Color.adaptiveMuted.opacity(0.15))
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(days) { day in
                        HStack(alignment: .top, spacing: 12) {
                            // Weekday label: bold, fixed width for alignment (e.g., "Mon.", "Tues.")
                            Text(formatWeekdayLabel(day.label))
                                .font(.interBody)
                                .fontWeight(.bold)
                                .foregroundColor(Color.adaptiveText)
                                .frame(width: 48, alignment: .leading)
                            
                            // Detail text with risk level prefix
                            // CRITICAL: Allow this HStack to expand to fill available width
                            HStack(alignment: .top, spacing: 6) {
                                // Risk level: bold, colored with box background
                                let riskLevel = extractRiskLevel(day.detail)
                                let riskColor: Color = {
                                    switch riskLevel {
                                    case "High": 
                                        // Brighter red for dark mode, darker red for light mode for better contrast
                                        return colorScheme == .dark ? Color(hex: "#FF4444") : Color(hex: "#CC0000")
                                    case "Moderate": 
                                        // Brighter orange for dark mode, darker orange for light mode
                                        return colorScheme == .dark ? Color(hex: "#FF9500") : Color(hex: "#E67E00")
                                    default: 
                                        // Low - brighter green for dark mode, maintain brand green for light mode
                                        return colorScheme == .dark ? Color(hex: "#4ECDC4") : Color(hex: "#888779")
                                    }
                                }()
                                
                                let backgroundColor: Color = {
                                    switch riskLevel {
                                    case "High": 
                                        // Colored box for both light and dark mode
                                        return colorScheme == .dark ? Color(hex: "#FF4444").opacity(0.2) : Color(hex: "#CC0000").opacity(0.15)
                                    case "Moderate": 
                                        // Colored box for both light and dark mode
                                        return colorScheme == .dark ? Color(hex: "#FF9500").opacity(0.2) : Color(hex: "#E67E00").opacity(0.15)
                                    default: 
                                        // Colored box for both light and dark mode
                                        return colorScheme == .dark ? Color(hex: "#4ECDC4").opacity(0.2) : Color(hex: "#888779").opacity(0.15)
                                    }
                                }()
                                
                                // Risk level with colored box
                                Text(riskLevel)
                                    .font(.interCaption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(riskColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(backgroundColor)
                                    .cornerRadius(6)
                                
                                // Detail text: regular, lighter gray, left-aligned
                                // IMPORTANT: Use fixedSize to prevent truncation - allow text to wrap fully
                                let cleanedDetail = removeRiskLevelFromDetail(day.detail)
                                if !cleanedDetail.isEmpty {
                                    Text(cleanedDetail)
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveMuted)
                                        .fixedSize(horizontal: false, vertical: true) // Allow wrapping to prevent truncation
                                } else {
                                    // If no descriptor found, show a default based on risk level
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
                                        .fixedSize(horizontal: false, vertical: true) // Allow wrapping
                                }
                                
                                // Spacer to push content to the left and allow text to expand
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading) // Expand to fill available width
                        }
                    }
                }
            }
            
            // Medical disclaimer (always shown first)
            Text("Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.")
                .font(.interSmall)
                .foregroundColor(Color.adaptiveMuted)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
            
            // Sources section (if any) - shown after disclaimer
            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.adaptiveMuted.opacity(0.15))
                        .padding(.top, 8)
                    Text("Sources")
                        .font(.interCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveMuted)
                    ForEach(sources, id: \.self) { source in
                        Text("• \(source)")
                            .font(.interCaption)
                            .foregroundColor(Color.adaptiveMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

// Sign-up prompt banner (shown when not authenticated)
private struct SignUpPromptBanner: View {
    @Environment(\.colorScheme) var colorScheme
    let onSignUp: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Get Personalized Insights")
                    .font(.interBody.weight(.semibold))
                    .foregroundColor(Color.adaptiveText)
                
                Text("Sign up to receive insights tailored to your conditions")
                    .font(.interCaption)
                    .foregroundColor(Color.adaptiveMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(action: onSignUp) {
                Text("Sign Up")
                    .font(.interBody.weight(.semibold))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colorScheme == .dark ? Color(hex: "#4ECDC4") : Color(hex: "#888779"))
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// Apple Weather Attribution View (required by App Store Guideline 5.2.5)
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
                .foregroundColor(colorScheme == .dark ? Color(hex: "#4ECDC4") : Color(hex: "#888779"))
                .underline()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

