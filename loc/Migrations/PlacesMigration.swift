import FirebaseFirestore
import MapboxSearch
import Foundation

class PlacesMigration {
    private let firestoreService = FirestoreService()
    private let mapboxSearchService = MapboxSearchService()
    private let db = Firestore.firestore()

    func runMigration() {
        print("Starting migration to update OpenHours for all places...")
        
        db.collection("places").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching places: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No places found in Firestore.")
                return
            }
            
            print("Found \(documents.count) places to process.")
            
            let dispatchGroup = DispatchGroup()
            
            for document in documents {
                do {
                    let place = try document.data(as: DetailPlace.self)
                    guard let mapboxId = place.mapboxId else {
                        print("Skipping place '\(place.name)' - No mapboxId found.")
                        continue
                    }
                    
                    dispatchGroup.enter()
                    self.updateOpenHours(for: place, mapboxId: mapboxId, documentId: document.documentID) {
                        dispatchGroup.leave()
                    }
                    
                } catch {
                    print("Error decoding place \(document.documentID): \(error.localizedDescription)")
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                print("Migration completed!")
                NotificationCenter.default.post(name: NSNotification.Name("MigrationCompleted"), object: nil)
            }
        }
    }
    
    private func updateOpenHours(for place: DetailPlace, mapboxId: String, documentId: String, completion: @escaping () -> Void) {
        mapboxSearchService.retrievePlaceById(mapboxId: mapboxId) { [weak self] result in
            guard let self = self else {
                completion()
                return
            }
            
            switch result {
            case .success(let searchResult):
                let newOpenHours: [String]?
                if let openHours = searchResult.metadata?.openHours as? OpenHours {
                    newOpenHours = DetailPlace.serializeOpenHours(openHours)
                } else {
                    newOpenHours = nil
                }
                
                self.db.collection("places").document(documentId).updateData([
                    "OpenHours": newOpenHours as Any
                ]) { error in
                    if let error = error {
                        print("Error updating OpenHours for place '\(place.name)': \(error.localizedDescription)")
                    } else {
                        print("Successfully updated OpenHours for place '\(place.name)'")
                    }
                    completion()
                }
                
            case .failure(let error):
                print("Failed to retrieve Mapbox data for place '\(place.name)': \(error.localizedDescription)")
                completion()
            }
        }
    }
}
