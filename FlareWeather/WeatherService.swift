import Foundation
import CoreLocation

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
    private let session = URLSession.shared
    
    // OpenWeatherMap API key - should be set in Xcode scheme environment variables or Info.plist
    // Get your free API key from: https://openweathermap.org/api
    private var apiKey: String {
        // First try to get from environment variable (set in Xcode scheme)
        if let key = ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"], !key.isEmpty {
            print("✅ WeatherService: API key found in environment variable")
            return key
        }
        
        // Second, try to get from Info.plist
        if let key = Bundle.main.infoDictionary?["OpenWeatherAPIKey"] as? String, !key.isEmpty {
            print("✅ WeatherService: API key found in Info.plist")
            return key
        }
        
        // Fallback: return empty string (will use mock data)
        print("⚠️ WeatherService: No API key found in environment or Info.plist")
        return ""
    }
    
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    private let forecastURL = "https://api.openweathermap.org/data/2.5/forecast"
    private let airPollutionURL = "https://api.openweathermap.org/data/2.5/air_pollution"
    
    init() {
        // Load cached data if available
        if let cache = weatherCache, !cache.isExpired {
            self.weatherData = cache.data
        }
    }
    
    func fetchWeatherData(for location: CLLocation, forceRefresh: Bool = false) async {
        print("🌤️ WeatherService: fetchWeatherData called for location: \(location.coordinate.latitude), \(location.coordinate.longitude) (forceRefresh: \(forceRefresh))")
        
        // Check API key first to trigger debug message
        let key = apiKey
        print("🔑 WeatherService: API key check - key length: \(key.count)")
        
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
        
        // If no API key, use mock data
        guard !apiKey.isEmpty else {
            print("⚠️ WeatherService: No API key found, using mock data")
            await MainActor.run {
                let mockWeatherData = WeatherData(
                    temperature: 22.0,
                    humidity: 65.0,
                    pressure: 1013.25,
                    windSpeed: 5.0,
                    condition: "Partly Cloudy",
                    timestamp: Date(),
                    location: "\(latitude), \(longitude)",
                    airQuality: nil
                )
                self.weatherData = mockWeatherData
                self.weatherCache = WeatherDataCache(data: mockWeatherData, timestamp: Date())
                self.isLoading = false
                self.errorMessage = "Using mock data - API key not configured"
            }
            return
        }
        
        print("🌤️ WeatherService: Fetching weather for \(latitude), \(longitude)")
        
        // Build API URL
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: "\(latitude)"),
            URLQueryItem(name: "lon", value: "\(longitude)"),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric") // Use Celsius
        ]
        
        guard let url = components?.url else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }
            
            print("🌤️ WeatherService: HTTP Status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    print("❌ WeatherService: Invalid API key (401)")
                    throw WeatherError.invalidAPIKey
                } else if httpResponse.statusCode == 404 {
                    print("❌ WeatherService: Location not found (404)")
                    throw WeatherError.locationNotFound
                } else {
                    print("❌ WeatherService: Server error (\(httpResponse.statusCode))")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    throw WeatherError.serverError(httpResponse.statusCode)
                }
            }
            
            let weatherResponse = try JSONDecoder().decode(OpenWeatherMapResponse.self, from: data)
            
            // Fetch air quality data in parallel
            let airQuality = await fetchAirQuality(latitude: latitude, longitude: longitude)
            
            let weatherData = convertToWeatherData(from: weatherResponse, location: "\(latitude), \(longitude)", airQuality: airQuality)
            
            print("✅ WeatherService: Successfully loaded weather data")
            
            await MainActor.run {
                self.weatherData = weatherData
                self.weatherCache = WeatherDataCache(data: weatherData, timestamp: Date())
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            print("❌ WeatherService: Error - \(error.localizedDescription)")
            
            // Fallback to mock data on error
            await MainActor.run {
                let mockWeatherData = WeatherData(
                    temperature: 22.0,
                    humidity: 65.0,
                    pressure: 1013.25,
                    windSpeed: 5.0,
                    condition: "Partly Cloudy",
                    timestamp: Date(),
                    location: "\(latitude), \(longitude)",
                    airQuality: nil
                )
                self.weatherData = mockWeatherData
                self.weatherCache = WeatherDataCache(data: mockWeatherData, timestamp: Date())
                self.isLoading = false
                self.errorMessage = "Using offline data: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchWeatherData(for city: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // If no API key, use mock data
        guard !apiKey.isEmpty else {
            await MainActor.run {
                let mockWeatherData = WeatherData(
                    temperature: 20.0,
                    humidity: 70.0,
                    pressure: 1015.0,
                    windSpeed: 3.0,
                    condition: "Sunny",
                    timestamp: Date(),
                    location: city,
                    airQuality: nil
                )
                self.weatherData = mockWeatherData
                self.weatherCache = WeatherDataCache(data: mockWeatherData, timestamp: Date())
                self.isLoading = false
            }
            return
        }
        
        // Build API URL for city search
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: city),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        
        guard let url = components?.url else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw WeatherError.invalidAPIKey
                } else if httpResponse.statusCode == 404 {
                    throw WeatherError.locationNotFound
                } else {
                    throw WeatherError.serverError(httpResponse.statusCode)
                }
            }
            
            let weatherResponse = try JSONDecoder().decode(OpenWeatherMapResponse.self, from: data)
            
            // Get coordinates from response for air quality fetch
            var latitude: Double? = nil
            var longitude: Double? = nil
            if let coord = weatherResponse.coord {
                latitude = coord.lat
                longitude = coord.lon
            }
            
            // Fetch air quality if coordinates available
            var airQuality: Int? = nil
            if let lat = latitude, let lon = longitude {
                airQuality = await fetchAirQuality(latitude: lat, longitude: lon)
            }
            
            let weatherData = convertToWeatherData(from: weatherResponse, location: city, airQuality: airQuality)
            
            await MainActor.run {
                self.weatherData = weatherData
                self.weatherCache = WeatherDataCache(data: weatherData, timestamp: Date())
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            // Fallback to mock data on error
            await MainActor.run {
                let mockWeatherData = WeatherData(
                    temperature: 20.0,
                    humidity: 70.0,
                    pressure: 1015.0,
                    windSpeed: 3.0,
                    condition: "Sunny",
                    timestamp: Date(),
                    location: city,
                    airQuality: nil
                )
                self.weatherData = mockWeatherData
                self.weatherCache = WeatherDataCache(data: mockWeatherData, timestamp: Date())
                self.isLoading = false
                self.errorMessage = "Using offline data: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshWeatherData(for location: CLLocation) async {
        weatherCache = nil
        forecastCache = nil
        forecastCacheTime = nil
        hourlyCache = nil
        hourlyCacheTime = nil
        await fetchWeatherData(for: location)
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
        
        // If no API key, skip forecast
        guard !apiKey.isEmpty else {
            await MainActor.run {
                isLoadingForecast = false
            }
            return
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        var components = URLComponents(string: forecastURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: "\(latitude)"),
            URLQueryItem(name: "lon", value: "\(longitude)"),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "cnt", value: "40") // Get 5 days (8 forecasts per day)
        ]
        
        guard let url = components?.url else {
            await MainActor.run {
                isLoadingForecast = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                await MainActor.run {
                    isLoadingForecast = false
                }
                return
            }
            
            let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)
            let dailyForecasts = processForecastData(forecastResponse)
            
            await MainActor.run {
                self.weeklyForecast = dailyForecasts
                self.forecastCache = dailyForecasts
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
    
    private func processForecastData(_ response: ForecastResponse) -> [DailyForecast] {
        let calendar = Calendar.current
        var dailyData: [Date: [ForecastItem]] = [:]
        
        // Group forecasts by day
        for item in response.list {
            let date = Date(timeIntervalSince1970: item.dt)
            let day = calendar.startOfDay(for: date)
            if dailyData[day] == nil {
                dailyData[day] = []
            }
            dailyData[day]?.append(item)
        }
        
        // Create daily forecasts (high, low, condition)
        var forecasts: [DailyForecast] = []
        let sortedDays = dailyData.keys.sorted()
        
        for day in sortedDays.prefix(7) { // Next 7 days
            guard let items = dailyData[day] else { continue }
            
            let temps = items.map { $0.main.temp }
            let highTemp = temps.max() ?? 0
            let lowTemp = temps.min() ?? 0
            
            // Use the most common condition for the day
            let conditions = items.map { $0.weather.first?.main ?? "Clear" }
            let mostCommon = Dictionary(grouping: conditions, by: { $0 })
                .max(by: { $0.value.count < $1.value.count })?.key ?? "Clear"
            
            // Get average humidity and pressure
            let avgHumidity = items.map { $0.main.humidity }.reduce(0, +) / Double(items.count)
            let avgPressure = items.map { $0.main.pressure }.reduce(0, +) / Double(items.count)
            
            // Get icon from midday forecast (or first available)
            let middayItem = items.first { item in
                let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: item.dt))
                return hour >= 12 && hour < 15
            } ?? items[items.count / 2]
            let icon = middayItem.weather.first?.icon ?? "01d"
            let description = middayItem.weather.first?.description.capitalized ?? mostCommon
            
            forecasts.append(DailyForecast(
                date: day,
                highTemp: highTemp,
                lowTemp: lowTemp,
                condition: description,
                icon: icon,
                humidity: avgHumidity,
                pressure: avgPressure
            ))
        }
        
        return forecasts
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
        
        // If no API key, skip hourly forecast
        guard !apiKey.isEmpty else {
            await MainActor.run {
                isLoadingHourly = false
            }
            return
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Use the same forecast endpoint but get more items (24 hours = 8 items * 3 hours)
        var components = URLComponents(string: forecastURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: "\(latitude)"),
            URLQueryItem(name: "lon", value: "\(longitude)"),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "cnt", value: "24") // Get 24 hours (8 forecasts * 3 hours = 24 hours)
        ]
        
        guard let url = components?.url else {
            await MainActor.run {
                isLoadingHourly = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                await MainActor.run {
                    isLoadingHourly = false
                }
                return
            }
            
            let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)
            let hourlyForecasts = processHourlyForecastData(forecastResponse)
            
            await MainActor.run {
                self.hourlyForecast = hourlyForecasts
                self.hourlyCache = hourlyForecasts
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
    
    private func processHourlyForecastData(_ response: ForecastResponse) -> [HourlyForecast] {
        let calendar = Calendar.current
        var hourlyForecasts: [HourlyForecast] = []
        
        // Get next 24 hours of forecasts
        let now = Date()
        let endTime = calendar.date(byAdding: .hour, value: 24, to: now) ?? now
        
        for item in response.list {
            let forecastTime = Date(timeIntervalSince1970: item.dt)
            
            // Only include forecasts within the next 24 hours
            if forecastTime > now && forecastTime <= endTime {
                // Convert wind speed from m/s to km/h if available
                let windSpeedKmh = (item.wind?.speed ?? 0) * 3.6
                
                let icon = item.weather.first?.icon ?? "01d"
                let condition = item.weather.first?.description.capitalized ?? "Clear"
                
                hourlyForecasts.append(HourlyForecast(
                    time: forecastTime,
                    temperature: item.main.temp,
                    condition: condition,
                    icon: icon,
                    humidity: item.main.humidity,
                    pressure: item.main.pressure,
                    windSpeed: windSpeedKmh
                ))
            }
        }
        
        // Sort by time
        hourlyForecasts.sort { $0.time < $1.time }
        
        return hourlyForecasts
    }
    
    private func fetchAirQuality(latitude: Double, longitude: Double) async -> Int? {
        // If no API key, return nil
        guard !apiKey.isEmpty else {
            return nil
        }
        
        var components = URLComponents(string: airPollutionURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: "\(latitude)"),
            URLQueryItem(name: "lon", value: "\(longitude)"),
            URLQueryItem(name: "appid", value: apiKey)
        ]
        
        guard let url = components?.url else {
            return nil
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ WeatherService: Air quality API error (\((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return nil
            }
            
            let airResponse = try JSONDecoder().decode(AirPollutionResponse.self, from: data)
            
            // Get the first (most recent) air quality reading
            if let firstData = airResponse.list.first {
                let aqi = firstData.main.aqi
                print("✅ WeatherService: Air quality AQI: \(aqi)")
                return aqi
            }
            
            return nil
        } catch {
            print("⚠️ WeatherService: Air quality fetch error - \(error.localizedDescription)")
            return nil
        }
    }
    
    private func convertToWeatherData(from response: OpenWeatherMapResponse, location: String, airQuality: Int? = nil) -> WeatherData {
        // Convert wind speed from m/s to km/h
        let windSpeedKmh = response.wind.speed * 3.6
        
        // Validate and sanitize values to prevent NaN
        let temp = response.main.temp.isFinite && !response.main.temp.isNaN ? response.main.temp : 0.0
        let humidity = response.main.humidity.isFinite && !response.main.humidity.isNaN ? response.main.humidity : 0.0
        let pressure = response.main.pressure.isFinite && !response.main.pressure.isNaN ? response.main.pressure : 1013.25
        let wind = windSpeedKmh.isFinite && !windSpeedKmh.isNaN ? windSpeedKmh : 0.0
        
        // Get weather description (first weather item)
        let condition = response.weather.first?.description.capitalized ?? "Unknown"
        
        return WeatherData(
            temperature: temp,
            humidity: humidity,
            pressure: pressure,
            windSpeed: wind,
            condition: condition,
            timestamp: Date(),
            location: response.name.isEmpty ? location : response.name,
            airQuality: airQuality
        )
    }
    
    private func getWeatherCondition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }
}

enum WeatherError: LocalizedError {
    case invalidResponse
    case invalidAPIKey
    case locationNotFound
    case serverError(Int)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from weather service"
        case .invalidAPIKey:
            return "Invalid API key. Please check your OpenWeatherMap API key."
        case .locationNotFound:
            return "Location not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}