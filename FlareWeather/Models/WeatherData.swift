import Foundation

struct WeatherData: Codable, Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let current: CurrentWeather
    let daily: DailyWeather
    let hourly: HourlyWeather
    
    struct CurrentWeather: Codable {
        let time: String
        let temperature2m: Double
        let relativeHumidity2m: Int
        let apparentTemperature: Double
        let precipitation: Double
        let rain: Double
        let showers: Double
        let snowfall: Double
        let weatherCode: Int
        let cloudCover: Int
        let pressureMsl: Double
        let surfacePressure: Double
        let windSpeed10m: Double
        let windDirection10m: Int
        let windGusts10m: Double
    }
    
    struct DailyWeather: Codable {
        let time: [String]
        let weatherCode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let apparentTemperatureMax: [Double]
        let apparentTemperatureMin: [Double]
        let precipitationSum: [Double]
        let rainSum: [Double]
        let showersSum: [Double]
        let snowfallSum: [Double]
        let precipitationHours: [Double]
        let precipitationProbabilityMax: [Int]
        let windSpeed10mMax: [Double]
        let windGusts10mMax: [Double]
        let windDirection10mDominant: [Int]
        let shortwaveRadiationSum: [Double]
        let et0FaoEvapotranspiration: [Double]
    }
    
    struct HourlyWeather: Codable {
        let time: [String]
        let temperature2m: [Double]
        let relativeHumidity2m: [Int]
        let apparentTemperature: [Double]
        let precipitation: [Double]
        let rain: [Double]
        let showers: [Double]
        let snowfall: [Double]
        let weatherCode: [Int]
        let cloudCover: [Int]
        let pressureMsl: [Double]
        let surfacePressure: [Double]
        let windSpeed10m: [Double]
        let windDirection10m: [Int]
        let windGusts10m: [Double]
        let visibility: [Double]
        let uvIndex: [Double]
        let uvIndexMax: [Double]
        let isDay: [Int]
    }
}

// MARK: - Weather Data Cache
class WeatherDataCache: ObservableObject {
    @Published var cachedData: WeatherData?
    @Published var lastUpdated: Date?
    
    private let cacheKey = "weather_data_cache"
    private let dateKey = "weather_data_date"
    
    init() {
        loadCachedData()
    }
    
    func cacheWeatherData(_ data: WeatherData) {
        cachedData = data
        lastUpdated = Date()
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: dateKey)
        }
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let weatherData = try? JSONDecoder().decode(WeatherData.self, from: data) {
            cachedData = weatherData
            lastUpdated = UserDefaults.standard.object(forKey: dateKey) as? Date
        }
    }
    
    func isCacheValid() -> Bool {
        guard let lastUpdated = lastUpdated else { return false }
        let cacheExpiration: TimeInterval = 3600 // 1 hour
        return Date().timeIntervalSince(lastUpdated) < cacheExpiration
    }
    
    func clearCache() {
        cachedData = nil
        lastUpdated = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }
}
