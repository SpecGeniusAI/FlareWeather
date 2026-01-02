import Foundation
import CoreLocation
import WeatherKit

class WeatherService: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var weeklyForecast: [DailyForecast] = []
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var isLoading = false
    @Published var isLoadingForecast = false
    @Published var isLoadingHourly = false
    @Published var errorMessage: String?
    
    private var weatherCache: WeatherDataCache?
    private var forecastCache: [DailyForecast]?
    private var forecastCacheTime: Date?
    private var hourlyCache: [HourlyForecast]?
    private var hourlyCacheTime: Date?
    private var lastLocation: CLLocation?
    
    // WeatherKit service instance
    // Note: Using typealias to avoid naming conflict with this class
    private let weatherKitService = WeatherKit.WeatherService.shared
    
    init() {
        print("✅ WeatherService: Initialized with WeatherKit (no API key needed)")
        // Load cached data if available
        if let cache = weatherCache, !cache.isExpired {
            self.weatherData = cache.data
        }
    }
    
    func fetchWeatherData(for location: CLLocation, forceRefresh: Bool = false) async {
        print("🌤️ WeatherService: fetchWeatherData called for location: \(location.coordinate.latitude), \(location.coordinate.longitude) (forceRefresh: \(forceRefresh))")
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Check if location changed - if so, clear cache
        if let lastLoc = lastLocation {
            let distance = lastLoc.distance(from: location)
            // If location changed by more than 1 km, clear cache
            if distance > 1000 {
                print("📍 WeatherService: Location changed by \(Int(distance))m, clearing cache")
                weatherCache = nil
                forecastCache = nil
                forecastCacheTime = nil
                hourlyCache = nil
                hourlyCacheTime = nil
            }
        }
        
        // Update last location
        lastLocation = location
        
        // Check cache first (unless forcing refresh)
        // If we have cached data, show it immediately and refresh in background
        let hasCachedData = !forceRefresh && weatherCache != nil && !weatherCache!.isExpired
        
        if hasCachedData {
            // Show cached data immediately without loading spinner
            await MainActor.run {
                self.weatherData = weatherCache!.data
                self.isLoading = false
                self.errorMessage = nil
            }
            
            // Refresh in background if data is getting old (but not expired yet)
            let age = Date().timeIntervalSince(weatherCache!.timestamp)
            if age > 10 * 60 { // Refresh if older than 10 minutes (but cache is valid for 30)
                print("🌤️ WeatherService: Cached data is \(Int(age / 60)) minutes old, refreshing in background...")
                // Refresh in background without blocking UI
                Task.detached(priority: .background) {
                    await self.fetchWeatherDataInBackground(for: location)
                }
            }
            return
        }
        
        // No cached data or forcing refresh - show loading spinner
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        await fetchWeatherDataFromAPI(for: location, latitude: latitude, longitude: longitude)
    }
    
    // Internal method to fetch weather from API (used by both foreground and background fetches)
    private func fetchWeatherDataFromAPI(for location: CLLocation, latitude: Double, longitude: Double) async {
        print("🌤️ WeatherService: Fetching weather from WeatherKit for \(latitude), \(longitude)")
        
        do {
            // Fetch current weather using WeatherKit
            let weather = try await weatherKitService.weather(for: location)
            
            // Convert WeatherKit response to our WeatherData model
            let currentWeather = weather.currentWeather
            
            // Temperature in Celsius
            let temperature = currentWeather.temperature.converted(to: UnitTemperature.celsius).value
            
            // Humidity (0.0-1.0 in WeatherKit, convert to percentage)
            let humidity = currentWeather.humidity * 100.0
            
            // Pressure (WeatherKit provides in hPa directly)
            // Note: Pressure is always available in CurrentWeather
            let pressureValue = currentWeather.pressure.converted(to: UnitPressure.hectopascals).value
            
            // Wind speed (convert from m/s to km/h)
            let windSpeed = currentWeather.wind.speed.converted(to: UnitSpeed.kilometersPerHour).value
            
            // Condition description
            let condition = currentWeather.condition.description
            
            // Get air quality if available (iOS 16.2+)
            // Note: WeatherKit air quality access may vary by iOS version
            // For now, checking currentWeather for air quality properties
            var airQuality: Int? = nil
            if #available(iOS 16.2, *) {
                // Try to access air quality from currentWeather if available
                // Air quality might not be available in all regions or iOS versions
                // WeatherKit may provide this through a different API call or property
                // For now, set to nil - air quality support will be added when confirmed available
                airQuality = nil
            }
            
            // Validate and sanitize values to prevent NaN
            let temp = temperature.isFinite && !temperature.isNaN ? temperature : 0.0
            let hum = humidity.isFinite && !humidity.isNaN ? humidity : 0.0
            let press = pressureValue.isFinite && !pressureValue.isNaN ? pressureValue : 1013.25
            let wind = windSpeed.isFinite && !windSpeed.isNaN ? windSpeed : 0.0
            
            let weatherData = WeatherData(
                temperature: temp,
                humidity: hum,
                pressure: press,
                windSpeed: wind,
                condition: condition,
                timestamp: Date(),
                location: nil, // Will be set by reverse geocoding
                airQuality: airQuality
            )
            
            print("✅ WeatherService: Successfully loaded weather data from WeatherKit")
            print("   Temperature: \(temp)°C, Humidity: \(hum)%, Pressure: \(press) hPa, Wind: \(wind) km/h")
            
            await MainActor.run {
                self.weatherData = weatherData
                self.weatherCache = WeatherDataCache(data: weatherData, timestamp: Date())
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            print("❌ WeatherService: Error fetching weather from WeatherKit - \(error.localizedDescription)")
            print("❌ WeatherService: Error type: \(type(of: error))")
            
            await MainActor.run {
                self.isLoading = false

                // Only show error if we don't have cached data to fall back to
                if self.weatherData == nil {
                    // Provide user-friendly error messages
                    // WeatherKit errors are typically URLError or WeatherServiceError
                    let errorMessage: String
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet, .networkConnectionLost:
                            errorMessage = "Network error. Please check your internet connection."
                        case .timedOut:
                            errorMessage = "Request timed out. Please try again."
                        case .cannotFindHost, .cannotConnectToHost:
                            errorMessage = "Cannot connect to weather service. Please check your internet connection."
                        default:
                            errorMessage = "Network error: \(urlError.localizedDescription)"
                        }
                    } else {
                        // Check for WeatherKit authentication errors
                        let errorDescription = error.localizedDescription.lowercased()
                        if errorDescription.contains("jwt") || errorDescription.contains("authservice") || errorDescription.contains("weatherkit") {
                            errorMessage = "WeatherKit authentication error. Please ensure WeatherKit is properly configured in Apple Developer Portal."
                        } else {
                            // Generic error message for other WeatherKit errors
                            errorMessage = "Unable to fetch weather data: \(error.localizedDescription)"
                        }
                    }
                    self.errorMessage = errorMessage
                    print("⚠️ WeatherService: No cached weather data available")
                } else {
                    // We have cached data, so don't show error - just log it
                    print("⚠️ WeatherService: Failed to refresh, but using cached data")
                }
            }
        }
    }
    
    // Background fetch method - doesn't show loading spinner
    private func fetchWeatherDataInBackground(for location: CLLocation) async {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        await fetchWeatherDataFromAPI(for: location, latitude: latitude, longitude: longitude)
    }
    
    func fetchWeatherData(for city: String) async {
        // WeatherKit requires CLLocation, not city names
        // This method is kept for compatibility but will need location coordinates
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // For city lookup, we'd need to geocode the city name first
        // For now, show an error message
        await MainActor.run {
            self.isLoading = false
            self.errorMessage = "City lookup requires location coordinates. Please use location-based weather."
        }
    }
    
    func refreshWeatherData(for location: CLLocation) async {
        weatherCache = nil
        forecastCache = nil
        forecastCacheTime = nil
        hourlyCache = nil
        hourlyCacheTime = nil
        await fetchWeatherData(for: location, forceRefresh: true)
        await fetchWeeklyForecast(for: location)
        await fetchHourlyForecast(for: location)
    }
    
    func fetchWeeklyForecast(for location: CLLocation) async {
        // Check cache first (6 hour cache for forecasts)
        if let cache = forecastCache,
           let cacheTime = forecastCacheTime,
           Date().timeIntervalSince(cacheTime) < 21600 {
            await MainActor.run {
                self.weeklyForecast = cache
            }
            return
        }
        
        await MainActor.run {
            isLoadingForecast = true
        }
        
        print("🌤️ WeatherService: Fetching weekly forecast from WeatherKit")
        
        do {
            // Fetch base weather first (includes dailyForecast and hourlyForecast properties)
            let weather = try await weatherKitService.weather(for: location)
            
            // Get current weather for baseline pressure/humidity
            let currentPressure = weather.currentWeather.pressure.converted(to: UnitPressure.hectopascals).value
            let currentHumidity = weather.currentWeather.humidity * 100.0
            
            // Get hourly forecast to estimate daily pressure/humidity
            let hourlyForecast = Array(weather.hourlyForecast.prefix(168)) // Next 7 days (24h * 7)
            
            // Access the daily forecast - it's a Forecast<DayWeather> collection
            // Convert to array and take first 7 days
            let forecasts: [DailyForecast] = weather.dailyForecast.prefix(7).enumerated().map { index, dayWeather in
                // Temperature in Celsius
                let highTemp = dayWeather.highTemperature.converted(to: UnitTemperature.celsius).value
                let lowTemp = dayWeather.lowTemperature.converted(to: UnitTemperature.celsius).value
                
                // Condition description
                let condition = dayWeather.condition.description
                
                // Get weather symbol name for icon (SF Symbol)
                let symbolName = dayWeather.symbolName
                
                // Validate values
                let high = highTemp.isFinite && !highTemp.isNaN ? highTemp : 0.0
                let low = lowTemp.isFinite && !lowTemp.isNaN ? lowTemp : 0.0
                
                // Estimate pressure and humidity from hourly forecast for this day
                // DayWeather doesn't have pressure/humidity, so we estimate from hourly data
                let dayStart = dayWeather.date
                let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                // Find hourly forecasts for this day
                let dayHourlyForecasts = hourlyForecast.filter { hourWeather in
                    hourWeather.date >= dayStart && hourWeather.date < dayEnd
                }
                
                // Calculate average pressure and humidity for this day from hourly data
                var estimatedPressure = currentPressure
                var estimatedHumidity = currentHumidity
                
                if !dayHourlyForecasts.isEmpty {
                    let pressures = dayHourlyForecasts.compactMap { hourWeather -> Double? in
                        let pressure = hourWeather.pressure.converted(to: UnitPressure.hectopascals).value
                        return pressure.isFinite && !pressure.isNaN ? pressure : nil
                    }
                    let humidities = dayHourlyForecasts.compactMap { hourWeather -> Double? in
                        let humidity = hourWeather.humidity * 100.0
                        return humidity.isFinite && !humidity.isNaN ? humidity : nil
                    }
                    
                    if !pressures.isEmpty {
                        estimatedPressure = pressures.reduce(0, +) / Double(pressures.count)
                    }
                    if !humidities.isEmpty {
                        estimatedHumidity = humidities.reduce(0, +) / Double(humidities.count)
                    }
                } else {
                    // Fallback: use current values with slight variation based on day index
                    // This at least provides some variation for risk calculation
                    let dayOffset = Double(index)
                    estimatedPressure = currentPressure + (dayOffset * 0.5) // Small variation
                    estimatedHumidity = currentHumidity + (dayOffset * 1.0) // Small variation
                    print("⚠️ Day \(index) (\(dayWeather.date)): No hourly data, using fallback estimates")
                }
                
                print("📊 Day \(index) (\(dayWeather.date)): pressure=\(estimatedPressure:.1f)hPa, humidity=\(estimatedHumidity:.0f)%, temp=\(high)/\(low)°C, hourly_count=\(dayHourlyForecasts.count)")
                
                return DailyForecast(
                    date: dayWeather.date,
                    highTemp: high,
                    lowTemp: low,
                    condition: condition,
                    icon: symbolName, // WeatherKit uses SF Symbols (e.g., "sun.max.fill")
                    humidity: estimatedHumidity,
                    pressure: estimatedPressure
                )
            }
            
            print("✅ WeatherService: Successfully loaded \(forecasts.count) days of forecast")
            
            await MainActor.run {
                self.weeklyForecast = forecasts
                self.forecastCache = forecasts
                self.forecastCacheTime = Date()
                self.isLoadingForecast = false
            }
        } catch {
            print("❌ WeatherService: Forecast error - \(error.localizedDescription)")
            await MainActor.run {
                isLoadingForecast = false
            }
        }
    }
    
    func fetchHourlyForecast(for location: CLLocation) async {
        // Check cache first (1 hour cache for hourly forecasts)
        if let cache = hourlyCache,
           let cacheTime = hourlyCacheTime,
           Date().timeIntervalSince(cacheTime) < 3600 {
            await MainActor.run {
                self.hourlyForecast = cache
            }
            return
        }
        
        await MainActor.run {
            isLoadingHourly = true
        }
        
        print("🌤️ WeatherService: Fetching hourly forecast from WeatherKit")
        
        do {
            // Fetch base weather first (includes hourlyForecast property)
            let weather = try await weatherKitService.weather(for: location)
            
            // Get next 24 hours
            let now = Date()
            let endTime = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now
            
            // Convert WeatherKit hourly forecast to our HourlyForecast model
            // Forecast<HourWeather> is a collection - iterate directly
            let forecasts: [HourlyForecast] = weather.hourlyForecast
                .filter { hourWeather in
                    let forecastTime = hourWeather.date
                    return forecastTime > now && forecastTime <= endTime
                }
                .map { hourWeather in
                    // Temperature in Celsius
                    let temperature = hourWeather.temperature.converted(to: UnitTemperature.celsius).value
                    
                    // Condition description
                    let condition = hourWeather.condition.description
                    
                    // Humidity (0.0-1.0 in WeatherKit, convert to percentage)
                    let humidity = hourWeather.humidity * 100.0
                    
                    // Pressure (WeatherKit provides in hPa)
                    // Note: Pressure is always available in HourWeather
                    let pressureValue = hourWeather.pressure.converted(to: UnitPressure.hectopascals).value
                    
                    // Wind speed (convert from m/s to km/h)
                    let windSpeed = hourWeather.wind.speed.converted(to: UnitSpeed.kilometersPerHour).value
                    
                    // Get weather symbol name (SF Symbol)
                    let symbolName = hourWeather.symbolName
                    
                    // Validate values
                    let temp = temperature.isFinite && !temperature.isNaN ? temperature : 0.0
                    let hum = humidity.isFinite && !humidity.isNaN ? humidity : 0.0
                    let press = pressureValue.isFinite && !pressureValue.isNaN ? pressureValue : 1013.25
                    let wind = windSpeed.isFinite && !windSpeed.isNaN ? windSpeed : 0.0
                    
                    return HourlyForecast(
                        time: hourWeather.date,
                        temperature: temp,
                        condition: condition,
                        icon: symbolName, // WeatherKit uses SF Symbols (e.g., "cloud.fill")
                        humidity: hum,
                        pressure: press,
                        windSpeed: wind
                    )
                }
                .sorted { $0.time < $1.time }
            
            print("✅ WeatherService: Successfully loaded \(forecasts.count) hours of forecast")
            
            await MainActor.run {
                self.hourlyForecast = forecasts
                self.hourlyCache = forecasts
                self.hourlyCacheTime = Date()
                self.isLoadingHourly = false
            }
        } catch {
            print("❌ WeatherService: Hourly forecast error - \(error.localizedDescription)")
            await MainActor.run {
                isLoadingHourly = false
            }
        }
    }
}

// WeatherKit uses standard Swift errors (URLError, etc.)
// No custom error enum needed
