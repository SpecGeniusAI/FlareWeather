import SwiftUI
import CoreData

struct LogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedSymptom = "Headache"
    @State private var severity = 3
    @State private var notes = ""
    @State private var showingSuccess = false
    
    let symptomTypes = ["Headache", "Dizziness", "Fatigue", "Nausea", "Joint Pain", "Other"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Symptom Details Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Symptom Details")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Symptom Type")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                            
                            Picker("Symptom Type", selection: $selectedSymptom) {
                                ForEach(symptomTypes, id: \.self) { symptom in
                                    Text(symptom).tag(symptom)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color.adaptiveText)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Severity: \(severity)/10")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                            
                            Slider(value: Binding(
                                get: { Double(severity) },
                                set: { severity = Int($0) }
                            ), in: 1...10, step: 1)
                            .accentColor(Color.adaptiveCardBackground)
                            
                            HStack {
                                Text("Mild")
                                    .font(.interSmall)
                                    .foregroundColor(Color.muted)
                                Spacer()
                                Text("Moderate")
                                    .font(.interSmall)
                                    .foregroundColor(Color.muted)
                                Spacer()
                                Text("Severe")
                                    .font(.interSmall)
                                    .foregroundColor(Color.muted)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Notes Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "note.text")
                                .font(.title3)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Notes")
                                .font(.interHeadline)
                                .foregroundColor(Color.adaptiveText)
                            
                            Spacer()
                        }
                        
                        TextField("Additional notes...", text: $notes, axis: .vertical)
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveText)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(Color.adaptiveBackground)
                            .cornerRadius(12)
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Submit Button
                    Button("Log Symptom") {
                        logSymptom()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .disabled(selectedSymptom.isEmpty)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Log Symptom")
            .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
            .alert("Symptom Logged", isPresented: $showingSuccess) {
                Button("OK") {
                    resetForm()
                }
            } message: {
                Text("Your symptom has been successfully logged.")
            }
        }
    }
    
    private func logSymptom() {
        let newSymptom = SymptomEntry(context: viewContext)
        newSymptom.id = UUID()
        newSymptom.timestamp = Date()
        newSymptom.symptomType = selectedSymptom
        newSymptom.severity = Int32(severity)
        newSymptom.notes = notes.isEmpty ? nil : notes
        newSymptom.location = "Current Location" // TODO: Get actual location
        
        do {
            try viewContext.save()
            showingSuccess = true
        } catch {
            print("Error saving symptom: \(error)")
        }
    }
    
    private func resetForm() {
        selectedSymptom = "Headache"
        severity = 3
        notes = ""
    }
}

#Preview {
    LogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
