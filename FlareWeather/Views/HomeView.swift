import SwiftUI
import CoreLocation

struct HomeView: View {
    @StateObject private var weatherService = WeatherService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var aiService = AIInsightsService()
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Weather Card
                    WeatherCardView(weatherData: weatherService.weatherData)
                        .padding(.horizontal)
                    
                    // AI Insights Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("AI Insights")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if aiService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text(aiService.insightMessage)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    // Quick Log Card
                    QuickLogCardView()
                        .padding(.horizontal)
                    
                    // Recent Symptoms
                    RecentSymptomsView()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color("Blue"), Color("Violet"), Color("Rose")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("FlareWeather")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if let location = locationManager.location {
                    Task {
                        await weatherService.fetchWeatherData(for: location)
                    }
                }
            }
            .task {
                // Mock data for now; later pull from CoreData
                let symptoms = [
                    SymptomEntryPayload(timestamp: "2025-10-19T08:00:00Z", symptom_type: "Pain", severity: 8),
                    SymptomEntryPayload(timestamp: "2025-10-19T12:00:00Z", symptom_type: "Fatigue", severity: 6)
                ]
                let weather = [
                    WeatherSnapshotPayload(timestamp: "2025-10-19T08:00:00Z", temperature: 18.5, humidity: 80, pressure: 1007, wind: 15),
                    WeatherSnapshotPayload(timestamp: "2025-10-19T12:00:00Z", temperature: 20.1, humidity: 78, pressure: 1005, wind: 22)
                ]
                await aiService.analyze(symptoms: symptoms, weather: weather)
            }
        }
    }
}

struct WeatherCardView: View {
    let weatherData: WeatherData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Current Weather")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if let weather = weatherData {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(weather.current.temperature2m))°C")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Feels like \(Int(weather.current.apparentTemperature))°C")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Humidity: \(weather.current.relativeHumidity2m)%")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    HStack {
                        Image(systemName: "wind")
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(Int(weather.current.windSpeed10m)) km/h")
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Image(systemName: "barometer")
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(Int(weather.current.pressureMsl)) hPa")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .font(.subheadline)
                }
            } else {
                Text("Loading weather data...")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
    }
}

struct AISummaryCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("AI Insights")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Weather patterns suggest increased migraine risk today.")
                    .font(.body)
                    .foregroundColor(.white)
                
                Text("Recommendation: Stay hydrated and consider indoor activities.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
    }
}

struct QuickLogCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Quick Log")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("Headache") {
                    // Quick log headache
                }
                .buttonStyle(QuickLogButtonStyle())
                
                Button("Dizziness") {
                    // Quick log dizziness
                }
                .buttonStyle(QuickLogButtonStyle())
                
                Button("Fatigue") {
                    // Quick log fatigue
                }
                .buttonStyle(QuickLogButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
    }
}

struct QuickLogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.2))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct RecentSymptomsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SymptomEntry.timestamp, ascending: false)],
        predicate: NSPredicate(format: "timestamp >= %@", Calendar.current.startOfDay(for: Date()) as NSDate),
        animation: .default)
    private var recentSymptoms: FetchedResults<SymptomEntry>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Today's Symptoms")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if recentSymptoms.isEmpty {
                Text("No symptoms logged today")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                ForEach(recentSymptoms.prefix(3), id: \.id) { symptom in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(symptom.symptomType ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            if let timestamp = symptom.timestamp {
                                Text(timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                        
                        Text("Severity: \(symptom.severity)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
