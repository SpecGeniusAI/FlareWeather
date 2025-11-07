import Foundation
import CoreData

struct SymptomEntryPayload: Codable {
    let timestamp: String
    let symptom_type: String
    let severity: Int
}

struct WeatherSnapshotPayload: Codable {
    let timestamp: String
    let temperature: Double
    let humidity: Double
    let pressure: Double
    let wind: Double
}

struct CorrelationRequest: Codable {
    let symptoms: [SymptomEntryPayload]
    let weather: [WeatherSnapshotPayload]
    let hourly_forecast: [WeatherSnapshotPayload]?
    let weekly_forecast: [WeatherSnapshotPayload]?
    let user_id: String?
    let diagnoses: [String]?
    
    init(symptoms: [SymptomEntryPayload], weather: [WeatherSnapshotPayload], hourly_forecast: [WeatherSnapshotPayload]? = nil, weekly_forecast: [WeatherSnapshotPayload]? = nil, user_id: String? = nil, diagnoses: [String]? = nil) {
        self.symptoms = symptoms
        self.weather = weather
        self.hourly_forecast = hourly_forecast
        self.weekly_forecast = weekly_forecast
        self.user_id = user_id
        self.diagnoses = diagnoses
    }
}

struct InsightResponse: Codable {
    let correlation_summary: String
    let strongest_factors: [String: Double]
    let ai_message: String
    let citations: [String]?  // Optional list of source filenames from RAG
    let risk: String?  // LOW, MODERATE, or HIGH
    let forecast: String?  // 1-sentence forecast message
    let why: String?  // Plain-language explanation for the risk
    let weekly_forecast_insight: String?  // Weekly forecast preview insight
}

@MainActor
final class AIInsightsService: ObservableObject {
    @Published var insightMessage: String = "Analyzing your week…"
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var citations: [String] = []
    @Published var lastAnalysisTime: Date? = nil
    @Published var risk: String? = nil  // LOW, MODERATE, or HIGH
    @Published var forecast: String? = nil  // 1-sentence forecast
    @Published var why: String? = nil  // Explanation
    @Published var weeklyForecastInsight: String? = nil  // Weekly forecast preview
    
    // Backend URL - configurable via environment variable or Info.plist
    // For local testing, use: "http://localhost:8000"
    // For production, use: "https://flareweather-production.up.railway.app"
    private var baseURL: String {
        // First try to get from environment variable (set in Xcode scheme)
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"], !url.isEmpty {
            print("✅ AIInsightsService: Backend URL found in environment variable: \(url)")
            return url
        }
        
        // Second, try to get from Info.plist
        if let url = Bundle.main.infoDictionary?["BackendURL"] as? String, !url.isEmpty {
            print("✅ AIInsightsService: Backend URL found in Info.plist: \(url)")
            return url
        }
        
        // Default: use localhost for development
        // Change this to production URL when ready to deploy
        let defaultURL = "http://localhost:8000"
        print("⚠️ AIInsightsService: Using default backend URL: \(defaultURL)")
        print("   To change: Set BACKEND_URL environment variable in Xcode scheme or add BackendURL to Info.plist")
        return defaultURL
    }
    
    // Request tracking to ignore stale responses
    private var currentRequestId: UUID? = nil
    private var task: Task<Void, Never>? = nil
    
    // Session caching - track analysis inputs to avoid redundant API calls
    private var lastAnalysisInputs: String? = nil
    private var hasAnalysisInSession = false
    
    func analyze(symptoms: [SymptomEntryPayload], weather: [WeatherSnapshotPayload], hourlyForecast: [WeatherSnapshotPayload]? = nil, weeklyForecast: [WeatherSnapshotPayload]? = nil, diagnoses: [String]? = nil) async {
        // Cancel any existing request
        task?.cancel()
        
        // Create new request ID
        let requestId = UUID()
        currentRequestId = requestId
        
        // Set loading state (but don't clear previous data yet - keep it visible while loading)
        isLoading = true
        // Only clear data if we don't have cached results
        if !hasAnalysisInSession {
            risk = nil
            forecast = nil
            why = nil
            insightMessage = "Analyzing weather patterns…"
        } else {
            // Keep existing data visible while new analysis loads
            insightMessage = "Updating analysis…"
        }
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/analyze") else {
            print("❌ Invalid URL: \(baseURL)/analyze")
            isLoading = false
            return
        }
        
        let requestBody = CorrelationRequest(
            symptoms: symptoms,
            weather: weather,
            hourly_forecast: hourlyForecast,
            weekly_forecast: weeklyForecast,
            user_id: nil,
            diagnoses: diagnoses
        )
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            print("❌ Failed to encode request body")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        print("📤 Sending request to: \(url) [Request ID: \(requestId)]")
        
        // Create task to track this request
        task = Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check if this request was cancelled or superseded
                guard !Task.isCancelled, currentRequestId == requestId else {
                    print("⏭️  Request \(requestId) was cancelled or superseded")
                    return
                }
                
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("📥 Response status: \(http.statusCode) [Request ID: \(requestId)]")
                
                guard (200..<300).contains(http.statusCode) else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                
                let decoded = try JSONDecoder().decode(InsightResponse.self, from: data)
                
                // Double-check this is still the current request
                guard currentRequestId == requestId else {
                    print("⏭️  Response for request \(requestId) ignored (newer request in progress)")
                    return
                }
                
                // Update UI only if this is the latest request
                insightMessage = decoded.ai_message
                citations = decoded.citations ?? []
                risk = decoded.risk
                forecast = decoded.forecast
                why = decoded.why
                weeklyForecastInsight = decoded.weekly_forecast_insight
                isLoading = false
                lastAnalysisTime = Date()
                
                print("✅ Success! Received insight [Request ID: \(requestId)]")
                print("📊 Risk: \(risk ?? "Unknown")")
                print("📋 Forecast: \(forecast ?? "None")")
            } catch {
                // Only update error if this is still the current request
                guard currentRequestId == requestId else {
                    print("⏭️  Error for request \(requestId) ignored (newer request in progress)")
                    return
                }
                
                print("❌ Error: \(error.localizedDescription) [Request ID: \(requestId)]")
                errorMessage = error.localizedDescription
                insightMessage = "Unable to analyze data right now. Check if backend is running on \(baseURL)"
                citations = []
                risk = nil
                forecast = nil
                why = nil
                weeklyForecastInsight = nil
                isLoading = false
            }
        }
        
        await task?.value
    }
    
    func analyzeWithRealData(context: NSManagedObjectContext? = nil, weatherService: WeatherService? = nil, userProfile: UserProfile? = nil) async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var symptoms: [SymptomEntryPayload] = []
        var weather: [WeatherSnapshotPayload] = []
        
        // Try to fetch real symptoms from CoreData
        if let context = context {
            let request: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
            // Get last 30 days of symptoms
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            request.predicate = NSPredicate(format: "timestamp >= %@", thirtyDaysAgo as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.timestamp, ascending: true)]
            
            do {
                let symptomEntries = try context.fetch(request)
                print("📊 Found \(symptomEntries.count) symptom entries in CoreData")
                
                for entry in symptomEntries {
                    if let timestamp = entry.timestamp,
                       let symptomType = entry.symptomType {
                        symptoms.append(SymptomEntryPayload(
                            timestamp: formatter.string(from: timestamp),
                            symptom_type: symptomType,
                            severity: Int(entry.severity)
                        ))
                    }
                }
            } catch {
                print("❌ Error fetching symptoms: \(error)")
            }
        }
        
        // If no real symptoms, use mock data for testing
        if symptoms.isEmpty {
            print("⚠️  No symptoms found in CoreData, using mock data")
            let now = Date()
            symptoms = [
                SymptomEntryPayload(
                    timestamp: formatter.string(from: now.addingTimeInterval(-3600 * 2)),
                    symptom_type: "Headache",
                    severity: 8
                ),
                SymptomEntryPayload(
                    timestamp: formatter.string(from: now.addingTimeInterval(-3600)),
                    symptom_type: "Headache",
                    severity: 6
                )
            ]
        }
        
        // Try to get real weather data
        if let weatherService = weatherService, let weatherData = weatherService.weatherData {
            print("✅ Using real weather data: \(weatherData.temperature)°C, \(weatherData.humidity)% humidity, \(weatherData.pressure) hPa")
            // Use current weather data and create a snapshot for each symptom
            for symptom in symptoms {
                weather.append(WeatherSnapshotPayload(
                    timestamp: symptom.timestamp,
                    temperature: weatherData.temperature,
                    humidity: weatherData.humidity,
                    pressure: weatherData.pressure,
                    wind: weatherData.windSpeed
                ))
            }
        } else {
            print("⚠️  WeatherService or weatherData is nil")
        }
        
        // If no weather data, use mock data
        if weather.isEmpty {
            print("⚠️  No weather data available, using mock data")
            for symptom in symptoms {
                weather.append(WeatherSnapshotPayload(
                    timestamp: symptom.timestamp,
                    temperature: 18.5,
                    humidity: 80,
                    pressure: 1007,
                    wind: 15
                ))
            }
        }
        
        print("📤 Sending \(symptoms.count) symptoms and \(weather.count) weather snapshots to backend")
        // Get user diagnoses if available
        let diagnoses: [String]? = {
            if let diagnosesArray = userProfile?.value(forKey: "diagnoses") as? NSArray {
                return diagnosesArray as? [String]
            }
            return nil
        }()
        if let diagnoses = diagnoses, !diagnoses.isEmpty {
            print("🏥 Including diagnoses: \(diagnoses.joined(separator: ", "))")
        }
        
        await analyze(symptoms: symptoms, weather: weather, diagnoses: diagnoses)
        lastAnalysisTime = Date()
    }
    
    // New function for weather-only analysis (no symptoms)
    func analyzeWithWeatherOnly(weatherService: WeatherService? = nil, userProfile: UserProfile? = nil) async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var weather: [WeatherSnapshotPayload] = []
        var hourlyForecast: [WeatherSnapshotPayload] = []
        
        // Get current weather data
        var currentWeatherData: WeatherData? = nil
        if let weatherService = weatherService, let weatherData = weatherService.weatherData {
            print("✅ Using real weather data: \(weatherData.temperature)°C, \(weatherData.humidity)% humidity, \(weatherData.pressure) hPa")
            currentWeatherData = weatherData
            // Create a single weather snapshot for current conditions
            weather.append(WeatherSnapshotPayload(
                timestamp: formatter.string(from: Date()),
                temperature: weatherData.temperature,
                humidity: weatherData.humidity,
                pressure: weatherData.pressure,
                wind: weatherData.windSpeed
            ))
        } else {
            print("⚠️  No weather data available, using mock data")
            weather.append(WeatherSnapshotPayload(
                timestamp: formatter.string(from: Date()),
                temperature: 18.5,
                humidity: 80,
                pressure: 1007,
                wind: 15
            ))
        }
        
        // Get hourly forecast data if available
        var forecastData: [HourlyForecast] = []
        if let weatherService = weatherService {
            forecastData = weatherService.hourlyForecast
            for hourForecast in forecastData {
                hourlyForecast.append(WeatherSnapshotPayload(
                    timestamp: formatter.string(from: hourForecast.time),
                    temperature: hourForecast.temperature,
                    humidity: hourForecast.humidity,
                    pressure: hourForecast.pressure,
                    wind: hourForecast.windSpeed
                ))
            }
            print("📊 Prepared \(hourlyForecast.count) hourly forecast points for AI analysis")
        }
        
        // Get weekly forecast data if available
        var weeklyForecast: [WeatherSnapshotPayload] = []
        if let weatherService = weatherService {
            let weeklyForecastData = weatherService.weeklyForecast
            for dayForecast in weeklyForecastData {
                weeklyForecast.append(WeatherSnapshotPayload(
                    timestamp: formatter.string(from: dayForecast.date),
                    temperature: (dayForecast.highTemp + dayForecast.lowTemp) / 2, // Use average temp
                    humidity: dayForecast.humidity,
                    pressure: dayForecast.pressure,
                    wind: 0 // Wind not stored in DailyForecast
                ))
            }
            print("📊 Prepared \(weeklyForecast.count) daily forecast points for weekly insight")
        }
        
        // Get user diagnoses if available
        let diagnoses: [String]? = {
            if let diagnosesArray = userProfile?.value(forKey: "diagnoses") as? NSArray {
                return diagnosesArray as? [String]
            }
            return nil
        }()
        
        // Create a hash of the analysis inputs to detect changes
        let analysisInputsHash = createAnalysisInputsHash(
            weather: currentWeatherData,
            hourlyForecast: forecastData,
            weeklyForecast: weatherService?.weeklyForecast ?? [],
            diagnoses: diagnoses
        )
        
        // Check if inputs have changed or if this is the first analysis in the session
        if let lastHash = lastAnalysisInputs, lastHash == analysisInputsHash, hasAnalysisInSession {
            print("⏭️  Analysis inputs unchanged, skipping API call")
            print("   Last hash: \(lastHash)")
            print("   Current hash: \(analysisInputsHash)")
            return
        }
        
        print("🔄 Analysis inputs changed or first analysis, triggering new analysis")
        print("   Last hash: \(lastAnalysisInputs ?? "none")")
        print("   Current hash: \(analysisInputsHash)")
        lastAnalysisInputs = analysisInputsHash
        hasAnalysisInSession = true
        
        // Send request with empty symptoms array, hourly forecast, and weekly forecast
        await analyze(
            symptoms: [],
            weather: weather,
            hourlyForecast: hourlyForecast.isEmpty ? nil : hourlyForecast,
            weeklyForecast: weeklyForecast.isEmpty ? nil : weeklyForecast,
            diagnoses: diagnoses
        )
        lastAnalysisTime = Date()
    }
    
    // Create a hash of analysis inputs to detect changes
    private func createAnalysisInputsHash(weather: WeatherData?, hourlyForecast: [HourlyForecast], weeklyForecast: [DailyForecast], diagnoses: [String]?) -> String {
        var components: [String] = []
        
        // Add current weather data (rounded to detect meaningful changes)
        // Use more aggressive rounding to avoid tiny fluctuations triggering new analysis
        if let weather = weather {
            // Round to whole numbers to avoid tiny decimal differences
            let temp = round(weather.temperature)
            let humidity = round(weather.humidity)
            let pressure = round(weather.pressure)
            let wind = round(weather.windSpeed)
            components.append("W:\(String(format: "%.0f", temp))_\(String(format: "%.0f", humidity))_\(String(format: "%.0f", pressure))_\(String(format: "%.0f", wind))")
        } else {
            components.append("W:none")
        }
        
        // Add hourly forecast summary (first 8 hours for key changes)
        // Track pressure changes which are most relevant for symptom triggers
        if hourlyForecast.count > 0 {
            let keyHours = Array(hourlyForecast.prefix(8))
            var forecastString = "F:"
            for hour in keyHours {
                // Round pressure to whole numbers
                let roundedPressure = round(hour.pressure)
                forecastString += "\(String(format: "%.0f", roundedPressure))_"
            }
            components.append(forecastString)
        } else {
            components.append("F:none")
        }
        
        // Add weekly forecast summary (first 3 days for key changes)
        if weeklyForecast.count > 0 {
            let keyDays = Array(weeklyForecast.prefix(3))
            var weeklyString = "WK:"
            for day in keyDays {
                // Round pressure to whole numbers
                let roundedPressure = round(day.pressure)
                weeklyString += "\(String(format: "%.0f", roundedPressure))_"
            }
            components.append(weeklyString)
        } else {
            components.append("WK:none")
        }
        
        // Add diagnoses (sorted for consistent hash)
        if let diagnoses = diagnoses, !diagnoses.isEmpty {
            components.append("D:\(diagnoses.sorted().joined(separator: ","))")
        } else {
            components.append("D:none")
        }
        
        return components.joined(separator: "|")
    }
}