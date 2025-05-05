import Foundation
import RealmSwift

class CachedImage: Object {
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted var data: Data?
    @Persisted var dateAdded: Date = Date()
    @Persisted var lastAccessed: Date = Date()
    
    convenience init(id: String, data: Data) {
        self.init()
        self.id = id
        self.data = data
        self.dateAdded = Date()
        self.lastAccessed = Date()
    }
} 