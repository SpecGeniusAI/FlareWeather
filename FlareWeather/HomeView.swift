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
    @StateObject private var weatherService = WeatherService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var aiService = AIInsightsService()
    @State private var showingOnboarding = false
    @State private var lastRefreshTime: Date? = nil
    @State private var aiFeedback: Bool? = nil
    @State private var hasInitialAnalysis = false
    @State private var isManualInsightRefresh = false
    @AppStorage("useFahrenheit") private var useFahrenheit = false
    @AppStorage("hasGeneratedDailyInsightSession") private var hasGeneratedDailyInsightSession = false
    
    // Helper function to refresh analysis
    private func refreshAnalysis(force: Bool = false) async {
        // The AIInsightsService now handles caching based on input changes
        // So we can call it more freely - it will only analyze if inputs changed
        
        print("🔄 HomeView: Refreshing analysis...")
        
        // Fetch user profile for diagnoses
        let userRequest: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        userRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: false)]
        let userProfile = try? viewContext.fetch(userRequest).first
        
        await aiService.analyzeWithWeatherOnly(
            weatherService: weatherService,
            userProfile: userProfile,
            force: force
        )
        
        lastRefreshTime = Date()
    }
    
    // Handle view appear
    private func handleViewAppear() {
        print("🏠 HomeView: Appeared")
        print("📍 HomeView: Location auth status: \(locationManager.authorizationStatus.rawValue)")
        print("📍 HomeView: useDeviceLocation: \(locationManager.useDeviceLocation)")
        print("🧠 HomeView: Has initial analysis: \(hasInitialAnalysis)")
        
        // Request location (will use manual if set)
        locationManager.requestLocation()
        
        // Only fetch weather if we don't have data yet or if this is the first appear
        // This prevents refiring when navigating back from Settings
        if !hasInitialAnalysis || weatherService.weatherData == nil {
            print("🌤️ HomeView: No weather data or first appear, fetching weather...")
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                if let location = getEffectiveLocation() {
                    print("📍 HomeView: Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    // Only force refresh if we don't have data
                    await weatherService.fetchWeatherData(for: location, forceRefresh: !hasInitialAnalysis)
                    await weatherService.fetchWeeklyForecast(for: location)
                    await weatherService.fetchHourlyForecast(for: location)
                } else {
                    print("⚠️ HomeView: No location available yet")
                }
            }
        } else {
            print("⏭️ HomeView: Already have weather data and analysis, skipping refresh")
        }
    }
    
    // Handle location change
    private func handleLocationChange(_ new: CLLocation?) {
        guard let location = new else { return }
        print("🌤️ HomeView: Location changed to \(location.coordinate.latitude), \(location.coordinate.longitude), fetching weather...")
        Task {
            // Force refresh when location changes to ensure we get fresh data
            await weatherService.fetchWeatherData(for: location, forceRefresh: true)
            await weatherService.fetchWeeklyForecast(for: location)
            await weatherService.fetchHourlyForecast(for: location)
            await refreshAnalysis()
        }
    }
    
    // Get effective location (device or manual)
    private func getEffectiveLocation() -> CLLocation? {
        return locationManager.getCurrentLocation()
    }
    
    // Handle weather data change
    private func handleWeatherDataChange(_ newData: WeatherData?) {
        guard let location = getEffectiveLocation() else { return }
        print("🌤️ HomeView: Weather data updated, fetching forecast...")
        print("🧠 HomeView: Has initial analysis: \(hasInitialAnalysis)")
        
        Task {
            // Fetch forecast when weather data becomes available
            await weatherService.fetchWeeklyForecast(for: location)
            await weatherService.fetchHourlyForecast(for: location)
            
            // Only refresh analysis if we don't have initial analysis yet
            // The caching in AIInsightsService will prevent redundant calls if inputs haven't changed
            if !hasInitialAnalysis {
                print("🔄 HomeView: No initial analysis yet, triggering analysis...")
                await refreshAnalysis()
            } else {
                print("⏭️ HomeView: Already have initial analysis, skipping analysis refresh")
            }
        }
    }
    
    // Check if weather data values actually changed
    private func weatherDataValuesChanged(old: WeatherData?, new: WeatherData?) -> Bool {
        guard let old = old, let new = new else {
            return new != nil // New data if old is nil but new exists
        }
        return old.temperature != new.temperature ||
               old.pressure != new.pressure ||
               old.humidity != new.humidity ||
               old.windSpeed != new.windSpeed
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
                await weatherService.fetchWeeklyForecast(for: location)
                await weatherService.fetchHourlyForecast(for: location)
                await refreshAnalysis()
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
            // Flare Risk Card
            FlareRiskCardView(
                risk: aiService.risk,
                forecast: aiService.forecast,
                isLoading: aiService.isLoading
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
            
            // Weekly Forecast Card
            WeeklyForecastCardView(
                forecasts: weatherService.weeklyForecast,
                isLoading: weatherService.isLoadingForecast
            )
            .padding(.horizontal)
            .cardEnterAnimation(delay: 0.4)
            
            // Weekly Forecast Insight Card
            let weeklySummary = aiService.weeklyInsightSummary ?? aiService.weeklyForecastInsight
            if (weeklySummary != nil && !(weeklySummary ?? "").isEmpty) || !aiService.weeklyInsightDays.isEmpty {
                WeeklyForecastInsightCardView(
                    summary: weeklySummary ?? "",
                    days: aiService.weeklyInsightDays,
                    sources: aiService.weeklyInsightSources
                )
                    .cardEnterAnimation(delay: 0.5)
            }
        }
        .padding(.vertical)
    }
    
    private var aiInsightsCard: some View {
        DailyInsightCardView(
            title: "Daily AI Insight",
            subtitle: "Today's Health Analysis",
            icon: "lightbulb.fill",
            message: aiService.insightMessage.isEmpty ? "Analyzing weather patterns…" : aiService.insightMessage,
            supportNote: aiService.supportNote,
            personalAnecdote: aiService.personalAnecdote,
            behaviorPrompt: aiService.behaviorPrompt,
            citations: aiService.citations,
            disclaimerText: "Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.",
            isLoading: aiService.isLoading,
            isRefreshing: isManualInsightRefresh,
            showRefreshButton: true,
            showFeedbackPrompt: true,
            onRefresh: {
                guard !isManualInsightRefresh else { return }
                isManualInsightRefresh = true
                Task {
                    await refreshAnalysis(force: true)
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
    }
    
    var body: some View {
        NavigationView {
            scrollViewWithModifiers
        }
    }
    
    private var scrollViewWithModifiers: some View {
        scrollViewContent
            .background(backgroundView)
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
            .onAppear(perform: handleViewAppearAction)
            .onChange(of: locationManager.location) { _, new in
                handleLocationChange(new)
            }
            .onChange(of: locationManager.useDeviceLocation) { _, new in
                handleLocationPreferenceChange(new)
            }
            .onChange(of: weatherService.weatherData) { old, new in
                handleWeatherDataChangeWithCheck(old: old, new: new)
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
    }
    
    private func handleRefresh() async {
        if let location = getEffectiveLocation() {
            await weatherService.refreshWeatherData(for: location)
        }
        await refreshAnalysis(force: true)
    }
    
    private var scrollViewContent: some View {
        ScrollView {
            contentView
        }
    }
    
    private func handleViewAppearAction() {
        hasInitialAnalysis = hasGeneratedDailyInsightSession
        handleViewAppear()
        if !hasGeneratedDailyInsightSession {
            Task {
                await refreshAnalysis()
                hasInitialAnalysis = true
                hasGeneratedDailyInsightSession = true
            }
        } else {
            print("⏭️ HomeView: Already have initial analysis, skipping onAppear refresh")
        }
    }
    
    private func handleWeatherDataChangeWithCheck(old: WeatherData?, new: WeatherData?) {
        if weatherDataValuesChanged(old: old, new: new) {
            print("🌤️ HomeView: Weather data values actually changed")
            handleWeatherDataChange(new)
        } else {
            print("⏭️ HomeView: Weather data instance changed but values are the same, skipping")
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
        
        let summary = blocks.first ?? ""
        var why: String?
        var comfort: String?
        var signOff: String?
        
        for block in blocks.dropFirst() {
            if block.hasPrefix("Why:") {
                let trimmed = block.dropFirst("Why:".count)
                why = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if block.hasPrefix("Comfort tip:") {
                let trimmed = block.dropFirst("Comfort tip:".count)
                comfort = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                signOff = block
            }
        }
        
        // Prevent duplicate: if sign-off is the same as comfort tip, remove it
        if let comfort = comfort, let signOff = signOff {
            if comfort.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == 
               signOff.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
                return (summary, why, comfort, nil)
            }
            // Also check if comfort tip contains the sign-off text
            if comfort.lowercased().contains(signOff.lowercased()) || 
               signOff.lowercased().contains(comfort.lowercased()) {
                return (summary, why, comfort, nil)
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
                    
                    // Closing line
                    if let signOff = sections.signOff, !signOff.isEmpty {
                        Text(signOff)
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    
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
                                Image(systemName: "pencil.and.list")
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
                    
                    Text("Sources")
                        .font(.interCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveMuted)
                    
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
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(days) { day in
                        HStack(alignment: .top, spacing: 12) {
                            // Weekday label: bold, fixed width for alignment (e.g., "Mon.", "Tues.")
                            // Increased width to prevent wrapping of detail text
                            Text(formatWeekdayLabel(day.label))
                                .font(.interBody)
                                .fontWeight(.bold)
                                .foregroundColor(Color.adaptiveText)
                                .frame(width: 48, alignment: .leading) // Increased from 36 to 48 for more room
                            
                            // Detail text: regular, lighter gray, left-aligned
                            Text(day.detail)
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading) // Ensure left alignment
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

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

