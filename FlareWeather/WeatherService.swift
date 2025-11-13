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
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
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
        if !forceRefresh, let cache = weatherCache, !cache.isExpired {
            await MainActor.run {
                self.weatherData = cache.data
                self.isLoading = false
            }
            return
        }
        
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
                
                // Keep existing data if available
                if self.weatherData == nil {
                    print("⚠️ WeatherService: No cached weather data available")
                } else {
                    print("ℹ️ WeatherService: Keeping existing weather data due to error")
                }
            }
        }
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
            // Fetch base weather first (includes dailyForecast property)
            let weather = try await weatherKitService.weather(for: location)
            
            // Access the daily forecast - it's a Forecast<DayWeather> collection
            // Convert to array and take first 7 days
            let forecasts: [DailyForecast] = weather.dailyForecast.prefix(7).map { dayWeather in
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
                
                // Note: DayWeather doesn't have humidity or pressure properties
                // Use default values for daily forecasts
                let hum: Double = 50.0 // Default humidity
                let press: Double = 1013.25 // Default pressure
                
                return DailyForecast(
                    date: dayWeather.date,
                    highTemp: high,
                    lowTemp: low,
                    condition: condition,
                    icon: symbolName, // WeatherKit uses SF Symbols (e.g., "sun.max.fill")
                    humidity: hum,
                    pressure: press
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
