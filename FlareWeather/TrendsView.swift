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
                VStack(spacing: 16) {
                    // Symptom Frequency Chart
                    SymptomFrequencyChart(symptoms: Array(symptoms))
                        .padding(.horizontal)
                    
                    // Severity Trends
                    SeverityTrendsChart(symptoms: Array(symptoms))
                        .padding(.horizontal)
                    
                    // Weekly Summary
                    WeeklySummaryView(symptoms: Array(symptoms))
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Trends")
            .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
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
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                Text("Symptom Frequency")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
            }
            
            if symptomCounts.isEmpty {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(Color.muted)
                    Text("No data available")
                        .font(.interBody)
                        .foregroundColor(Color.muted)
                }
                .padding(.vertical, 20)
            } else {
                // Filter and validate data before charting
                let validData = symptomCounts.sorted(by: { $0.value > $1.value })
                    .filter { $0.value > 0 && $0.value < Int.max }
                
                if validData.isEmpty {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(Color.muted)
                        Text("No valid data available")
                            .font(.interBody)
                            .foregroundColor(Color.muted)
                    }
                    .padding(.vertical, 20)
                } else {
                    Chart(validData, id: \.key) { item in
                        let clampedCount = max(0, min(1000, item.value))
                        BarMark(
                            x: .value("Count", clampedCount),
                            y: .value("Symptom", item.key)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.adaptiveCardBackground,
                                    Color.adaptiveCardBackground.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.muted.opacity(0.3))
                            AxisValueLabel()
                                .foregroundStyle(Color.muted)
                                .font(.interCaption)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.muted.opacity(0.3))
                            AxisValueLabel()
                                .foregroundStyle(Color.muted)
                                .font(.interCaption)
                        }
                    }
                    .frame(height: max(200, min(600, CGFloat(validData.count) * 50.0))) // Clamp height to prevent NaN
                }
            }
        }
        .cardStyle()
    }
}

struct SeverityTrendsChart: View {
    let symptoms: [SymptomEntry]
    
    var weeklyData: [(Date, Double)] {
        guard !symptoms.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: symptoms) { symptom in
            calendar.startOfWeek(for: symptom.timestamp ?? Date())
        }
        
        return grouped.compactMap { (week, symptomList) in
            guard !symptomList.isEmpty else { return nil }
            let total = symptomList.reduce(0.0) { $0 + Double($1.severity) }
            let count = Double(symptomList.count)
            guard count > 0, total >= 0 else { return nil } // Changed > 0 to >= 0 to allow zero values
            let avgSeverity = total / count
            guard avgSeverity.isFinite && !avgSeverity.isNaN && avgSeverity >= 0 && avgSeverity <= 10 else { return nil }
            return (week, avgSeverity)
        }.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                Text("Severity Trends")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
            }
            
            if weeklyData.isEmpty {
                HStack {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .foregroundColor(Color.muted)
                    Text("No data available")
                        .font(.interBody)
                        .foregroundColor(Color.muted)
                }
                .padding(.vertical, 20)
            } else {
                // Filter and validate data before charting
                let validData = weeklyData.filter { item in
                    let value = item.1
                    return value.isFinite && !value.isNaN && value >= 0 && value <= 10
                }
                
                if validData.isEmpty {
                    HStack {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .foregroundColor(Color.muted)
                        Text("No valid data available")
                            .font(.interBody)
                            .foregroundColor(Color.muted)
                    }
                    .padding(.vertical, 20)
                } else {
                    Chart(validData, id: \.0) { item in
                        let clampedValue = max(0.0, min(10.0, item.1))
                        LineMark(
                            x: .value("Week", item.0),
                            y: .value("Severity", clampedValue)
                        )
                        .foregroundStyle(Color.adaptiveCardBackground)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol {
                            Circle()
                                .fill(Color.adaptiveCardBackground)
                                .frame(width: 8, height: 8)
                                .shadow(color: .black.opacity(0.1), radius: 2)
                        }
                        
                        AreaMark(
                            x: .value("Week", item.0),
                            y: .value("Severity", clampedValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.adaptiveCardBackground.opacity(0.3),
                                    Color.adaptiveCardBackground.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.muted.opacity(0.3))
                            AxisValueLabel()
                                .foregroundStyle(Color.muted)
                                .font(.interCaption)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.muted.opacity(0.3))
                            AxisValueLabel()
                                .foregroundStyle(Color.muted)
                                .font(.interCaption)
                        }
                    }
                    .frame(height: 220) // Fixed height to prevent NaN issues
                }
            }
        }
        .cardStyle()
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
    
    var avgSeverity: Int {
        guard !thisWeekSymptoms.isEmpty else { return 0 }
        let total = thisWeekSymptoms.reduce(0) { $0 + Int($1.severity) }
        guard total >= 0, thisWeekSymptoms.count > 0 else { return 0 }
        let avg = total / thisWeekSymptoms.count
        // Int can't be NaN, so just clamp the value
        return max(0, min(10, avg)) // Clamp between 0-10
    }
    
    var mostCommonSymptom: String? {
        guard !thisWeekSymptoms.isEmpty else { return nil }
        return Dictionary(grouping: thisWeekSymptoms, by: { $0.symptomType ?? "Unknown" })
            .max(by: { $0.value.count < $1.value.count })?.key
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(Color.adaptiveText)
                
                Text("This Week")
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                SummaryStatRow(
                    icon: "number.circle.fill",
                    title: "Total Symptoms",
                    value: "\(thisWeekSymptoms.count)",
                    color: .blue
                )
                
                if !thisWeekSymptoms.isEmpty {
                    SummaryStatRow(
                        icon: "chart.bar.fill",
                        title: "Average Severity",
                        value: "\(avgSeverity)/10",
                        color: .orange
                    )
                    
                    if let mostCommon = mostCommonSymptom {
                        SummaryStatRow(
                            icon: "star.fill",
                            title: "Most Common",
                            value: mostCommon,
                            color: .purple
                        )
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(Color.muted)
                        Text("No symptoms this week")
                            .font(.interBody)
                            .foregroundColor(Color.muted)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .cardStyle()
    }
}

struct SummaryStatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.interCaption)
                    .foregroundColor(Color.muted)
                
                Text(value)
                    .font(.interHeadline)
                    .foregroundColor(Color.adaptiveText)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
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
