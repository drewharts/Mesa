import FirebaseFirestore
import FirebaseStorage

struct FirebaseConfig {
    let db: Firestore
    let storage: Storage
    
    static let shared = FirebaseConfig()
    
    private init() {
        self.db = Firestore.firestore()
        self.storage = Storage.storage()
    }
}