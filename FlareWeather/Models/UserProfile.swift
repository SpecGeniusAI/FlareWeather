import Foundation
import CoreData

@objc(UserProfile)
public class UserProfile: NSManagedObject {
    
}

extension UserProfile {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProfile> {
        return NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }
    
    @NSManaged public var name: String?
    @NSManaged public var age: Int32
    @NSManaged public var location: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension UserProfile: Identifiable {
    
}
