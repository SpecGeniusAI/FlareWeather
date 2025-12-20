import Foundation

struct WeatherData: Codable, Identifiable, Equatable {
    let id: UUID
    let temperature: Double
    let humidity: Double
    let pressure: Double
    let windSpeed: Double
    let condition: String
    let timestamp: Date
    let location: String?
    let airQuality: Int? // Air Quality Index (1-5: 1=Good, 2=Fair, 3=Moderate, 4=Poor, 5=Very Poor)
    
    init(temperature: Double, humidity: Double, pressure: Double, windSpeed: Double, condition: String, timestamp: Date = Date(), location: String? = nil, airQuality: Int? = nil) {
        self.id = UUID()
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.windSpeed = windSpeed
        self.condition = condition
        self.timestamp = timestamp
        self.location = location
        self.airQuality = airQuality
    }
    
    // Equatable conformance
    static func == (lhs: WeatherData, rhs: WeatherData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.temperature == rhs.temperature &&
               lhs.humidity == rhs.humidity &&
               lhs.pressure == rhs.pressure &&
               lhs.windSpeed == rhs.windSpeed &&
               lhs.condition == rhs.condition &&
               lhs.timestamp == rhs.timestamp &&
               lhs.location == rhs.location &&
               lhs.airQuality == rhs.airQuality
    }
}

// OpenWeatherMap API Response Structure
struct OpenWeatherMapResponse: Codable {
    let main: MainWeather
    let wind: Wind
    let weather: [Weather]
    let name: String
    let coord: Coordinates?
}

struct MainWeather: Codable {
    let temp: Double // Temperature in Celsius (when units=metric)
    let humidity: Double // Humidity percentage
    let pressure: Double // Atmospheric pressure in hPa
}

struct Wind: Codable {
    let speed: Double // Wind speed in m/s (when units=metric)
    let deg: Double? // Wind direction in degrees
}

struct Weather: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

struct Coordinates: Codable {
    let lat: Double
    let lon: Double
}

// Legacy structures for backward compatibility (if needed)
struct WeatherResponse: Codable {
    let current: CurrentWeather
    let location: LocationInfo
}

struct CurrentWeather: Codable {
    let temp_c: Double
    let humidity: Double
    let pressure_mb: Double
    let wind_kph: Double
    let condition: WeatherCondition
}

struct WeatherCondition: Codable {
    let text: String
    let code: Int
}

struct LocationInfo: Codable {
    let name: String
    let region: String
    let country: String
}

struct WeatherDataCache {
    let data: WeatherData
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 1800 // 30 minutes - matches foreground refresh threshold
    }
}

// Weekly Forecast Models
struct DailyForecast: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let highTemp: Double
    let lowTemp: Double
    let condition: String
    let icon: String
    let humidity: Double
    let pressure: Double
}

// Hourly Forecast Models
struct HourlyForecast: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let condition: String
    let icon: String
    let humidity: Double
    let pressure: Double
    let windSpeed: Double
}

// OpenWeatherMap Forecast Response
struct ForecastResponse: Codable {
    let list: [ForecastItem]
    let city: ForecastCity
}

struct ForecastItem: Codable {
    let dt: TimeInterval
    let main: ForecastMain
    let weather: [ForecastWeather]
    let wind: ForecastWind?
    let dt_txt: String
}

struct ForecastWind: Codable {
    let speed: Double // Wind speed in m/s
    let deg: Double? // Wind direction in degrees
}

struct ForecastMain: Codable {
    let temp: Double
    let humidity: Double
    let pressure: Double
}

struct ForecastWeather: Codable {
    let main: String
    let description: String
    let icon: String
}

struct ForecastCity: Codable {
    let name: String
}

// Air Pollution API Response
struct AirPollutionResponse: Codable {
    let list: [AirPollutionData]
}

struct AirPollutionData: Codable {
    let main: AirQualityMain
}

struct AirQualityMain: Codable {
    let aqi: Int // Air Quality Index: 1=Good, 2=Fair, 3=Moderate, 4=Poor, 5=Very Poor
}
