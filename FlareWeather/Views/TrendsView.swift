import SwiftUI
import CoreData
import Charts

struct TrendsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SymptomEntry.timestamp, ascending: true)],
        animation: .default)
    private var symptoms: FetchedResults<SymptomEntry>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Symptom Frequency Chart
                    SymptomFrequencyChart(symptoms: Array(symptoms))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 10)
                        )
                    
                    // Severity Trends
                    SeverityTrendsChart(symptoms: Array(symptoms))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 10)
                        )
                    
                    // Weekly Summary
                    WeeklySummaryView(symptoms: Array(symptoms))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 10)
                        )
                }
                .padding()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color("Blue"), Color("Violet"), Color("Rose")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Trends")
        }
    }
}

struct SymptomFrequencyChart: View {
    let symptoms: [SymptomEntry]
    
    var symptomCounts: [String: Int] {
        Dictionary(grouping: symptoms, by: { $0.symptomType ?? "Unknown" })
            .mapValues { $0.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Symptom Frequency")
                .font(.headline)
                .foregroundColor(.white)
            
            if symptomCounts.isEmpty {
                Text("No data available")
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Chart(symptomCounts.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                    BarMark(
                        x: .value("Count", item.value),
                        y: .value("Symptom", item.key)
                    )
                    .foregroundStyle(.white.opacity(0.8))
                }
                .frame(height: 200)
            }
        }
    }
}

struct SeverityTrendsChart: View {
    let symptoms: [SymptomEntry]
    
    var weeklyData: [(Date, Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: symptoms) { symptom in
            calendar.startOfWeek(for: symptom.timestamp ?? Date())
        }
        
        return grouped.map { (week, symptoms) in
            let avgSeverity = symptoms.reduce(0) { $0 + Double($1.severity) } / Double(symptoms.count)
            return (week, avgSeverity)
        }.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Severity Trends")
                .font(.headline)
                .foregroundColor(.white)
            
            if weeklyData.isEmpty {
                Text("No data available")
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Chart(weeklyData, id: \.0) { item in
                    LineMark(
                        x: .value("Week", item.0),
                        y: .value("Severity", item.1)
                    )
                    .foregroundStyle(.white)
                    .symbol(Circle())
                }
                .frame(height: 200)
            }
        }
    }
}

struct WeeklySummaryView: View {
    let symptoms: [SymptomEntry]
    
    var thisWeekSymptoms: [SymptomEntry] {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfWeek(for: Date())
        return symptoms.filter { symptom in
            guard let timestamp = symptom.timestamp else { return false }
            return timestamp >= startOfWeek
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Symptoms: \(thisWeekSymptoms.count)")
                    .foregroundColor(.white.opacity(0.8))
                
                if !thisWeekSymptoms.isEmpty {
                    let avgSeverity = thisWeekSymptoms.reduce(0) { $0 + $1.severity } / thisWeekSymptoms.count
                    Text("Average Severity: \(avgSeverity)")
                        .foregroundColor(.white.opacity(0.8))
                    
                    let mostCommon = Dictionary(grouping: thisWeekSymptoms, by: { $0.symptomType ?? "Unknown" })
                        .max(by: { $0.value.count < $1.value.count })?.key
                    
                    if let mostCommon = mostCommon {
                        Text("Most Common: \(mostCommon)")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    TrendsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
