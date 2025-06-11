import Foundation
import Firebase

class PlaceService: ObservableObject {
    static let shared = PlaceService()
    private let db = FirebaseManager.shared.db
    
    private init() {}

    // Async version of fetchAllPlaces
    func fetchAllPlaces() async throws -> [DetailPlace] {
        return try await withCheckedThrowingContinuation { continuation in
            fetchAllPlaces { places, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: places ?? [])
            }
        }
    }

    // Fetch all places from Firestore
    func fetchAllPlaces(completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        print("Fetching all places from Firestore...")
        db.collection("places").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching places: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            guard let documents = snapshot?.documents else {
                print("No places found in Firestore.")
                completion([], nil)
                return
            }
            let places = documents.compactMap { try? $0.data(as: DetailPlace.self) }
            print("Fetched \(places.count) places.")
            completion(places, nil)
        }
    }

    func findPlace(mapboxId: String, completion: @escaping (DetailPlace?, Error?) -> Void) {
        // Reference to the Firestore collection where places are stored ("places")
        let db = Firestore.firestore()
        let placesCollection = db.collection("places")
        
        // Query where "mapboxId" matches the input
        placesCollection
            .whereField("mapboxId", isEqualTo: mapboxId)
            .limit(to: 1) // Assuming mapboxId is unique
            .getDocuments { (snapshot, error) in
                if let error = error {
                    // Return nil for DetailPlace and the error if the query fails
                    completion(nil, error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    // No matching document found
                    completion(nil, nil)
                    return
                }
                
                // Decode the document directly into DetailPlace
                do {
                    let detailPlace = try document.data(as: DetailPlace.self)
                    completion(detailPlace, nil)
                } catch {
                    // Return nil for DetailPlace and the decoding error
                    completion(nil, error)
                }
            }
    }

        func addPlaceToList(userId: String, listName: String, place: Place) {
        do {
            try db.collection("users").document(userId)
                .collection("placeLists").document(listName)
                .updateData(["places": FieldValue.arrayUnion([try Firestore.Encoder().encode(place)])])
        } catch {
            print("Error encoding place: \(error.localizedDescription)")
        }
    }
    
    func fetchPlace(withId placeId: String, completion: @escaping (Result<DetailPlace, Error>) -> Void) {
        let placeRef = db.collection("places").document(placeId)
        
        placeRef.getDocument { documentSnapshot, error in
            if let error = error {
                print("Error fetching place: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let documentSnapshot = documentSnapshot, documentSnapshot.exists else {
                let notFoundError = NSError(domain: "FirestoreService", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Place not found"
                ])
                completion(.failure(notFoundError))
                return
            }
            
            do {
                let detailPlace = try documentSnapshot.data(as: DetailPlace.self)
                completion(.success(detailPlace))
            } catch {
                print("Error decoding place: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func removePlaceFromList(userId: String, listId: UUID, place: Place) {
        let listIdString = listId.uuidString
        do {
            let encodedPlace = try Firestore.Encoder().encode(place)
            db.collection("users").document(userId)
                .collection("placeLists").document(listIdString)
                .updateData(["places": FieldValue.arrayRemove([encodedPlace])]) { error in
                    if let error = error {
                        print("Error removing place from list: \(error.localizedDescription)")
                    } else {
                        print("Place successfully removed from list: \(listIdString)")
                    }
                }
        } catch {
            print("Error encoding place for removal: \(error.localizedDescription)")
        }
    }



    func createNewList(placeList: PlaceList,userID: String) {
        do {
            let listIdString = placeList.id.uuidString // Convert UUID to String

            try db.collection("users").document(userID)
                .collection("placeLists").document(listIdString)
                .setData(from: placeList) { error in
                    if let error = error {
                        print("Error creating new list: \(error.localizedDescription)")
                    } else {
                        print("List successfully created: \(placeList.name)")
                    }
                }
        } catch {
            print("Error encoding listData: \(error.localizedDescription)")
        }
    }
    
    func deleteList(userId: String, listId: String, completion: @escaping (Error?) -> Void) {
        let listRef = db.collection("users").document(userId)
                        .collection("placeLists").document(listId)
        
        listRef.delete { error in
            if let error = error {
                print("Error deleting list '\(listId)': \(error.localizedDescription)")
            } else {
                print("List successfully deleted: \(listId)")
            }
            completion(error)
        }
    }
    
    
    func fetchList(userId: String, listName: String, completion: @escaping (Result<PlaceList, Error>) -> Void) {
        print("🔍 Attempting to fetch list for user \(userId) with name: \(listName)")
        db.collection("users").document(userId)
            .collection("placeLists").document(listName)
            .getDocument { document, error in
                if let error = error {
                    print("❌ Error fetching list \(listName) for user \(userId): \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let document = document, document.exists else {
                    print("⚠️ List not found - User: \(userId), List Name: \(listName)")
                    let notFoundError = NSError(domain: "FirestoreError", code: 404, userInfo: [NSLocalizedDescriptionKey: "List not found"])
                    completion(.failure(notFoundError))
                    return
                }

                do {
                    let placeList = try document.data(as: PlaceList.self)
                    print("✅ Successfully fetched list \(listName) for user \(userId)")
                    completion(.success(placeList))
                } catch {
                    print("❌ Error decoding list \(listName) for user \(userId): \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }


    
    func fetchLists(userId: String, completion: @escaping ([PlaceList]) -> Void) {
        db.collection("users").document(userId)
            .collection("placeLists").getDocuments { result, error in
                if let error = error {
                    print("Error fetching lists: \(error.localizedDescription)")
                    completion([]) // Return an empty array if there's an error
                } else {
                    let placeLists = result?.documents.compactMap { document in
                        try? document.data(as: PlaceList.self)
                    } ?? []
                    completion(placeLists) // Return the fetched place lists
                }
            }
    }

    func addToAllPlaces(detailPlace: DetailPlace, completion: @escaping (Error?) -> Void) {
        let detailPlaceId = detailPlace.id.uuidString // Convert UUID to String
        let placeRef = db.collection("places").document(detailPlaceId)
        
        do {
            try placeRef.setData(from: detailPlace) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }

    func addToMyPlaces(userId: String, detailPlace: DetailPlace, completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("users")
                .document(userId)
                .collection("myPlaces")
                .document(detailPlace.id.uuidString)
                .setData(from: detailPlace) { error in
                    if let error = error {
                        print("Error saving place to user's collection: \(error.localizedDescription)")
                    } else {
                        print("Successfully saved place to user's collection")
                    }
                    completion(error)
                }
        } catch {
            print("Error encoding place for user's collection: \(error.localizedDescription)")
            completion(error)
        }
    }

        func verifyOpenHoursField(completion: @escaping (Int, Int, Error?) -> Void) {
        db.collection("places").getDocuments { snapshot, error in
            if let error = error {
                completion(0, 0, error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(0, 0, nil)
                return
            }
            
            var hasField = 0
            var missingField = 0
            
            for document in documents {
                let data = document.data()
                if data["OpenHours"] != nil {
                    hasField += 1
                } else {
                    missingField += 1
                    print("⚠️ Place missing OpenHours: \(document.documentID)")
                }
            }
            
            print("""
                📊 OpenHours Field Verification:
                - Places with OpenHours: \(hasField)
                - Places missing OpenHours: \(missingField)
                - Total places: \(hasField + missingField)
                """)
            
            completion(hasField, missingField, nil)
        }
    }

    func updatePlace(detailPlace: DetailPlace, completion: @escaping (Error?) -> Void) {
        let placeRef = db.collection("places").document(detailPlace.id.uuidString)
        
        do {
            // Update the document with merge: true to only update specified fields
            try placeRef.setData(from: detailPlace, merge: true) { error in
                if let error = error {
                    print("Error updating place: \(error.localizedDescription)")
                } else {
                    print("Successfully updated place with ID: \(detailPlace.id.uuidString)")
                }
                completion(error)
            }
        } catch {
            print("Error encoding place data: \(error.localizedDescription)")
            completion(error)
        }
    }

    func getDetailPlace(placeId: String, completion: @escaping (DetailPlace?, Error?) -> Void) {
        fetchPlace(withId: placeId) { result in
            switch result {
            case .success(let place):
                completion(place, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }

    func fetchMyPlaces(userId: String, completion: @escaping ([DetailPlace]?) -> Void) {
        db.collection("users")
            .document(userId)
            .collection("myPlaces")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching myPlaces: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let detailPlaces = snapshot?.documents.compactMap {
                    try? $0.data(as: DetailPlace.self)
                } ?? []
                
                completion(detailPlaces)
            }
    }

    func fetchProfileFavorites(userId: String) async throws -> [DetailPlace] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchProfileFavorites(userId: userId) { places in
                continuation.resume(returning: places ?? [])
            }
        }
    }

        func fetchLists(userId: String) async throws -> [PlaceList] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchLists(userId: userId) { lists in
                continuation.resume(returning: lists)
            }
        }
    }
    
    func fetchPlace(withId placeId: String) async throws -> DetailPlace {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchPlace(withId: placeId) { result in
                switch result {
                case .success(let detailPlace):
                    continuation.resume(returning: detailPlace)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchMyPlaces(userId: String) async throws -> [DetailPlace] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchMyPlaces(userId: userId) { places in
                continuation.resume(returning: places ?? [])
            }
        }
    }
} 
