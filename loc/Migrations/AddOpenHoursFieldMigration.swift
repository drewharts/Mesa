import Firebase
import FirebaseCore

class AddOpenHoursFieldMigration {
    private let db = Firestore.firestore()
    
    func migrate(completion: @escaping (Error?) -> Void) {
        print("Starting AddOpenHours field migration...")
        
        db.collection("places").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching places: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ No places found in database")
                completion(nil)
                return
            }
            
            print("📝 Found \(documents.count) places to process")
            
            let batch = self.db.batch()
            var updatedCount = 0
            var skippedCount = 0
            
            for document in documents {
                let data = document.data()
                // Only add OpenHours if it doesn't exist
                if data["OpenHours"] == nil {
                    let placeRef = self.db.collection("places").document(document.documentID)
                    batch.updateData(["OpenHours": [String]()], forDocument: placeRef)
                    updatedCount += 1
                } else {
                    skippedCount += 1
                }
            }
            
            // Commit the batch
            batch.commit { error in
                if let error = error {
                    print("❌ Error updating places: \(error.localizedDescription)")
                    completion(error)
                } else {
                    print("""
                        ✅ AddOpenHours migration completed:
                        - Added empty OpenHours to \(updatedCount) places
                        - Skipped \(skippedCount) places (already had OpenHours)
                        - Total processed: \(updatedCount + skippedCount) places
                        """)
                    completion(nil)
                }
            }
        }
    }
} 