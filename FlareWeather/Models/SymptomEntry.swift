import Foundation
import CoreData

@objc(SymptomEntry)
public class SymptomEntry: NSManagedObject {
    
}

extension SymptomEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SymptomEntry> {
        return NSFetchRequest<SymptomEntry>(entityName: "SymptomEntry")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var symptomType: String?
    @NSManaged public var severity: Int32
    @NSManaged public var notes: String?
    @NSManaged public var weatherData: Data?
    @NSManaged public var location: String?
}

extension SymptomEntry: Identifiable {
    
}
