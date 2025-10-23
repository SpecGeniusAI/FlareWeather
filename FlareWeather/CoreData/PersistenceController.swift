import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleUser = UserProfile(context: viewContext)
        sampleUser.name = "Sample User"
        sampleUser.age = 30
        sampleUser.location = "San Francisco, CA"
        sampleUser.createdAt = Date()
        sampleUser.updatedAt = Date()
        
        let sampleSymptom = SymptomEntry(context: viewContext)
        sampleSymptom.id = UUID()
        sampleSymptom.timestamp = Date()
        sampleSymptom.symptomType = "Headache"
        sampleSymptom.severity = 3
        sampleSymptom.notes = "Mild headache after weather change"
        sampleSymptom.location = "San Francisco, CA"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FlareWeatherModel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
