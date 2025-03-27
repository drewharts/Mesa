import FirebaseFirestore
import MapboxSearch
import Foundation
import FirebaseStorage

class PlacesMigration: SearchEngineDelegate {
    func suggestionsUpdated(suggestions: [any MapboxSearch.SearchSuggestion], searchEngine: MapboxSearch.SearchEngine) {
        // We don't need to handle suggestions since we're using retrieve directly
    }
    
    func resultResolved(result: any MapboxSearch.SearchResult, searchEngine: MapboxSearch.SearchEngine) {
        guard let (place, documentId) = currentPlace, let completion = currentCompletion else {
            return
        }
        
        let newOpenHours: [String]?
        if let openHours = result.metadata?.openHours as? OpenHours {
            newOpenHours = DetailPlace.serializeOpenHours(openHours)
        } else {
            newOpenHours = nil
        }
        
        db.collection("places").document(documentId).updateData([
            "OpenHours": newOpenHours as Any
        ]) { error in
            if let error = error {
                print("❌ Error updating OpenHours for place '\(place.name)': \(error.localizedDescription)")
            } else {
                print("✅ Successfully updated OpenHours for place '\(place.name)'")
            }
            self.currentPlace = nil
            self.currentCompletion = nil
            completion()
        }
    }
    
    func searchErrorHappened(searchError: MapboxSearch.SearchError, searchEngine: MapboxSearch.SearchEngine) {
        guard let (place, documentId) = currentPlace, let completion = currentCompletion else {
            return
        }
        
        if searchError.localizedDescription.contains("Too Many Requests") && retryCount < maxRetries {
            retryCount += 1
            print("⚠️ Rate limited for place '\(place.name)'. Retrying in \(rateLimitDelay * Double(retryCount)) seconds... (Attempt \(retryCount)/\(maxRetries))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + rateLimitDelay * Double(retryCount)) { [weak self] in
                guard let self = self else { return }
                let options = DetailsOptions()
                searchEngine.retrieve(mapboxID: place.mapboxId ?? "")
            }
            return
        }
        
        print("❌ Failed to retrieve Mapbox data for place '\(place.name)': \(searchError.localizedDescription)")
        self.currentPlace = nil
        self.currentCompletion = nil
        retryCount = 0
        completion()
    }
    
    private let db = Firestore.firestore()
    private let firestoreService = FirestoreService()
    private var mapboxSearchEngine: SearchEngine?
    private let queue = DispatchQueue(label: "com.loc.placesmigration", qos: .userInitiated)
    private var currentPlace: (place: DetailPlace, documentId: String)?
    private var currentCompletion: (() -> Void)?
    private let rateLimitDelay: TimeInterval = 1.0  // 1 second between requests
    private var retryCount = 0
    private let maxRetries = 3
    
    func migrate(completion: @escaping (Error?) -> Void) {
        print("Starting OpenHours migration...")
        
        // Initialize SearchEngine on the main thread
        DispatchQueue.main.sync {
            self.mapboxSearchEngine = SearchEngine()
            self.mapboxSearchEngine?.delegate = self
        }
        
        // First get all places
        db.collection("places").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { 
                print("Self was deallocated during migration")
                completion(nil)
                return 
            }
            
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
            
            let group = DispatchGroup()
            var migrationError: Error?
            var processedPlaces = 0
            var updatedPlaces = 0
            
            // Modify the chunk processing
            let chunkSize = 2  // Reduce chunk size
            let chunks = stride(from: 0, to: documents.count, by: chunkSize).map {
                Array(documents[$0..<min($0 + chunkSize, documents.count)])
            }
            
            for (chunkIndex, chunk) in chunks.enumerated() {
                // Add longer delay between chunks
                if chunkIndex > 0 {
                    Thread.sleep(forTimeInterval: 5.0) // 5 second delay between chunks
                }
                
                for document in chunk {
                    group.enter()
                    
                    do {
                        let place = try document.data(as: DetailPlace.self)
                        guard let mapboxId = place.mapboxId else {
                            print("⚠️ Skipping place '\(place.name)' - No mapboxId found")
                            group.leave()
                            continue
                        }
                        
                        print("Processing place: \(place.name)")
                        // Add delay between individual requests within a chunk
                        Thread.sleep(forTimeInterval: self.rateLimitDelay)
                        
                        self.updateOpenHours(for: place, mapboxId: mapboxId, documentId: document.documentID) {
                            processedPlaces += 1
                            updatedPlaces += 1
                            print("Progress: \(processedPlaces)/\(documents.count) places processed")
                            group.leave()
                        }
                        
                    } catch {
                        print("❌ Error decoding place \(document.documentID): \(error.localizedDescription)")
                        migrationError = error
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                // Clean up SearchEngine on main thread
                self.mapboxSearchEngine = nil
                
                print("✅ Migration completed!")
                print("📊 Summary:")
                print("   - Processed \(processedPlaces) places")
                print("   - Updated \(updatedPlaces) places")
                
                if let error = migrationError {
                    print("❌ Migration completed with errors: \(error.localizedDescription)")
                }
                
                completion(migrationError)
            }
        }
    }
    
    private func updateOpenHours(for place: DetailPlace, mapboxId: String, documentId: String, completion: @escaping () -> Void) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let searchEngine = self.mapboxSearchEngine else {
                print("Self or SearchEngine was deallocated during OpenHours update")
                completion()
                return
            }
            
            // Store current place and completion for use in delegate callback
            self.currentPlace = (place, documentId)
            self.currentCompletion = completion
            
            let options = DetailsOptions()
            searchEngine.retrieve(mapboxID: mapboxId, options: options)
        }
        
        DispatchQueue.main.async(execute: workItem)
    }
    
    // MARK: - SearchEngineDelegate Methods
    
    func searchEngine(_ searchEngine: SearchEngine, didRetrieve result: SearchResult) {
        guard let (place, documentId) = currentPlace, let completion = currentCompletion else {
            return
        }
        
        let newOpenHours: [String]?
        if let openHours = result.metadata?.openHours as? OpenHours {
            newOpenHours = DetailPlace.serializeOpenHours(openHours)
        } else {
            newOpenHours = nil
        }
        
        db.collection("places").document(documentId).updateData([
            "OpenHours": newOpenHours as Any
        ]) { error in
            if let error = error {
                print("❌ Error updating OpenHours for place '\(place.name)': \(error.localizedDescription)")
            } else {
                print("✅ Successfully updated OpenHours for place '\(place.name)'")
            }
            self.currentPlace = nil
            self.currentCompletion = nil
            completion()
        }
    }
    
    func searchEngine(_ searchEngine: SearchEngine, didFailToRetrieve error: SearchError) {
        guard let (place, _) = currentPlace, let completion = currentCompletion else {
            return
        }
        
        print("❌ Failed to retrieve Mapbox data for place '\(place.name)': \(error.localizedDescription)")
        self.currentPlace = nil
        self.currentCompletion = nil
        completion()
    }
}

