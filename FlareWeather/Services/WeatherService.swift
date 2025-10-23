import Foundation
import CoreLocation

class WeatherService: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cache = WeatherDataCache()
    private let session = URLSession.shared
    
    init() {
        // Load cached data if available
        if let cachedData = cache.cachedData, cache.isCacheValid() {
            self.weatherData = cachedData
        }
    }
    
    func fetchWeatherData(for location: CLLocation) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Check cache first
        if let cachedData = cache.cachedData, cache.isCacheValid() {
            await MainActor.run {
                self.weatherData = cachedData
                self.isLoading = false
            }
            return
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m&hourly=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility,uv_index,uv_index_max,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,shortwave_radiation_sum,et0_fao_evapotranspiration&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.errorMessage = "Failed to fetch weather data"
                    self.isLoading = false
                }
                return
            }
            
            let decoder = JSONDecoder()
            let weatherResponse = try decoder.decode(WeatherResponse.self, from: data)
            
            let weatherData = WeatherData(
                latitude: latitude,
                longitude: longitude,
                current: weatherResponse.current,
                daily: weatherResponse.daily,
                hourly: weatherResponse.hourly
            )
            
            await MainActor.run {
                self.weatherData = weatherData
                self.isLoading = false
            }
            
            // Cache the data
            cache.cacheWeatherData(weatherData)
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Error fetching weather data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func refreshWeatherData(for location: CLLocation) async {
        cache.clearCache()
        await fetchWeatherData(for: location)
    }
}

// MARK: - Open-Meteo API Response Models
private struct WeatherResponse: Codable {
    let latitude: Double
    let longitude: Double
    let current: WeatherData.CurrentWeather
    let daily: WeatherData.DailyWeather
    let hourly: WeatherData.HourlyWeather
}
