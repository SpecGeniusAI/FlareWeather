import Foundation

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
    let user_id: String? = nil
}

struct InsightResponse: Codable {
    let correlation_summary: String
    let strongest_factors: [String: Double]
    let ai_message: String
}

@MainActor
final class AIInsightsService: ObservableObject {
    @Published var insightMessage: String = "Analyzing your week…"
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let baseURL = "https://flareweather-production.up.railway.app"
    
    func analyze(symptoms: [SymptomEntryPayload], weather: [WeatherSnapshotPayload]) async {
        guard let url = URL(string: "\(baseURL)/analyze") else { return }
        isLoading = true
        defer { isLoading = false }
        
        let requestBody = CorrelationRequest(symptoms: symptoms, weather: weather)
        guard let jsonData = try? JSONEncoder().encode(requestBody) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(InsightResponse.self, from: data)
            insightMessage = decoded.ai_message
        } catch {
            errorMessage = error.localizedDescription
            insightMessage = "Unable to analyze data right now."
        }
    }
}