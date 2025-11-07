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
            Form {
                Section("Symptom Details") {
                    Picker("Symptom Type", selection: $selectedSymptom) {
                        ForEach(symptomTypes, id: \.self) { symptom in
                            Text(symptom).tag(symptom)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Severity: \(severity)")
                        Slider(value: Binding(
                            get: { Double(severity) },
                            set: { severity = Int($0) }
                        ), in: 1...10, step: 1)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Log Symptom") {
                        logSymptom()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(selectedSymptom.isEmpty)
                }
            }
            .navigationTitle("Log Symptom")
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
