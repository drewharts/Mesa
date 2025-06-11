import Foundation
import FirebaseFirestore
import FirebaseStorage

class FirebaseManager {
    static let shared = FirebaseManager()
    
    let db: Firestore
    let storage: Storage
    
    private init() {
        self.db = Firestore.firestore()
        self.storage = Storage.storage()
    }
} 