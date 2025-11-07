import SwiftUI
import CoreLocation
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var weatherService = WeatherService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var aiService = AIInsightsService()
    @State private var showingOnboarding = false
    @State private var lastRefreshTime: Date? = nil
    @State private var hasInitialAnalysis = false
    
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
            userProfile: userProfile
        )
        
        lastRefreshTime = Date()
    }
    
    // Handle view appear
    private func handleViewAppear() {
        print("🏠 HomeView: Appeared")
        print("📍 HomeView: Location auth status: \(locationManager.authorizationStatus.rawValue)")
        print("📍 HomeView: useDeviceLocation: \(locationManager.useDeviceLocation)")
        
        // Request location (will use manual if set)
        locationManager.requestLocation()
        
        // Give it a moment to load manual location if needed
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if let location = getEffectiveLocation() {
                print("🌤️ HomeView: Has location, fetching weather...")
                print("📍 HomeView: Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                // Force refresh when view appears to ensure we have the latest data
                await weatherService.fetchWeatherData(for: location, forceRefresh: true)
                await weatherService.fetchWeeklyForecast(for: location)
                await weatherService.fetchHourlyForecast(for: location)
            } else {
                print("⚠️ HomeView: No location available yet")
            }
        }
    }
    
    // Handle location change
    private func handleLocationChange(_ newLocation: CLLocation?) {
        guard let location = newLocation else { return }
        print("🌤️ HomeView: Location changed to \(location.coordinate.latitude), \(location.coordinate.longitude), fetching weather...")
        Task {
            // Force refresh when location changes to ensure we get fresh data
            await weatherService.fetchWeatherData(for: location, forceRefresh: true)
            await weatherService.fetchWeeklyForecast(for: location)
            await weatherService.fetchHourlyForecast(for: location)
            try? await Task.sleep(nanoseconds: 500_000_000)
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
        Task {
            // Fetch forecast when weather data becomes available
            await weatherService.fetchWeeklyForecast(for: location)
            await weatherService.fetchHourlyForecast(for: location)
            // Only refresh analysis if weather data actually changed (not just on view appear)
            // The caching in AIInsightsService will prevent redundant calls
            await refreshAnalysis()
        }
    }
    
    // Handle authorization status change
    private func handleAuthorizationStatusChange(_ newStatus: CLAuthorizationStatus) {
        print("📍 HomeView: Authorization status changed to: \(newStatus.rawValue)")
        if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
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
            return UserDefaults.standard.string(forKey: "manualLocation")
        } else {
            // Use location from weather data if available
            return weatherService.weatherData?.location
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
                isLoading: weatherService.isLoadingHourly
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
            if let weeklyInsight = aiService.weeklyForecastInsight, !weeklyInsight.isEmpty {
                WeeklyForecastInsightCardView(insight: weeklyInsight)
                    .cardEnterAnimation(delay: 0.5)
            }
        }
        .padding(.vertical)
    }
    
    // AI Insights Card
    private var aiInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily AI Insight")
                        .font(.interHeadline)
                        .foregroundColor(Color.adaptiveText)
                    Text("Today's Health Analysis")
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                }
                
                Spacer()
                
                if aiService.isLoading {
                    ProgressView()
                        .tint(Color.adaptiveText)
                        .scaleEffect(0.8)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.2), value: aiService.isLoading)
                }
            }
            
            if aiService.isLoading {
                // Show loading message while analyzing
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
                    Text(aiService.insightMessage)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveText)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.3), value: aiService.insightMessage)
                    
                    // Medical disclaimer
                    Text("Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.")
                        .font(.interSmall)
                        .foregroundColor(Color.adaptiveMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            
            // Sources footer
            if !aiService.citations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.adaptiveMuted.opacity(0.3))
                    
                    Text("Sources")
                        .font(.interCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveMuted)
                    
                    ForEach(aiService.citations, id: \.self) { citation in
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
        .padding(.horizontal)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                contentView
            }
            .background(backgroundView)
            .navigationTitle("FlareWeather")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
            .refreshable {
                if let location = getEffectiveLocation() {
                    await weatherService.refreshWeatherData(for: location)
                }
                await refreshAnalysis()
            }
            .onAppear {
                handleViewAppear()
                // Only refresh analysis on first appear or if we don't have analysis yet
                // The caching in AIInsightsService will handle preventing redundant calls
                if !hasInitialAnalysis {
                    Task {
                        // Small delay to ensure weather data is loaded first
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        await refreshAnalysis()
                        hasInitialAnalysis = true
                    }
                } else {
                    print("⏭️ HomeView: Already have initial analysis, skipping onAppear refresh")
                }
            }
            .onChange(of: locationManager.location) { oldLocation, newLocation in
                handleLocationChange(newLocation)
            }
            .onChange(of: locationManager.useDeviceLocation) { oldValue, newValue in
                print("🔄 HomeView: useDeviceLocation changed from \(oldValue) to \(newValue)")
                // Reload location when preference changes
                locationManager.loadManualLocation()
                // Wait a moment for location to update
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    if let location = getEffectiveLocation() {
                        print("🌤️ HomeView: Refreshing weather for new location preference...")
                        // Force refresh with new location
                        await weatherService.fetchWeatherData(for: location, forceRefresh: true)
                        await weatherService.fetchWeeklyForecast(for: location)
                        await weatherService.fetchHourlyForecast(for: location)
                        await refreshAnalysis()
                    }
                }
            }
            .onChange(of: weatherService.weatherData) { oldData, newData in
                handleWeatherDataChange(newData)
            }
            .onChange(of: locationManager.authorizationStatus) { oldStatus, newStatus in
                handleAuthorizationStatusChange(newStatus)
            }
        }
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
                                Text("\(Int(temp))°")
                                    .font(.system(size: 64, weight: .light))
                                    .foregroundColor(Color.adaptiveText)
                                    .contentTransition(.numericText())
                                
                                Text("C")
                                    .font(.title2)
                                    .foregroundColor(Color.adaptiveMuted)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(weather.condition)
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveText)
                                        .fontWeight(.medium)
                                    
                                    Text("Feels like \(Int(temp))°")
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
                                WeatherDetailView(icon: "barometer", value: "\(Int(pressure))", label: "hPa")
                                
                                // Air Quality
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
                        Text("\(Int(forecast.highTemp))°")
                            .font(.interBody)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.adaptiveText)
                            .contentTransition(.numericText())
                        Text("\(Int(forecast.lowTemp))°")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                            .contentTransition(.numericText())
                    }
                    .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func weatherIcon(for iconCode: String) -> String {
        // Map OpenWeatherMap icon codes to SF Symbols
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
            // Light amber/yellow in dark mode, deep rust in light mode
            return isDarkMode ? Color(hex: "#FFB84D") : Color(hex: "#B8681A")
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
                        ForEach(forecasts.prefix(24)) { forecast in
                            HourlyForecastRow(forecast: forecast, timeFormatter: timeFormatter)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .animation(.easeOut(duration: 0.3), value: forecasts.count)
            }
        }
        .cardStyle()
    }
}

struct HourlyForecastRow: View {
    let forecast: HourlyForecast
    let timeFormatter: DateFormatter
    
    private var isCurrentHour: Bool {
        Calendar.current.isDate(forecast.time, equalTo: Date(), toGranularity: .hour)
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
            Text("\(Int(forecast.temperature))°")
                .font(.interBody)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptiveText)
                .contentTransition(.numericText())
            
            // Pressure change indicator (if significant)
            if forecast.pressure < 1000 {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if forecast.pressure > 1020 {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else {
                Color.clear
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 60)
        .padding(.vertical, 8)
    }
    
    private func weatherIcon(for iconCode: String) -> String {
        // Map OpenWeatherMap icon codes to SF Symbols
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
    let insight: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly AI Insight")
                        .font(.interHeadline)
                        .foregroundColor(Color.adaptiveText)
                    Text("7-Day Symptom Outlook")
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                }
                
                Spacer()
            }
            
            Text(insight)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            
            // Medical disclaimer
            Text("Flare isn't a substitute for medical professionals, just a weather-aware wellness guide.")
                .font(.interSmall)
                .foregroundColor(Color.adaptiveMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
