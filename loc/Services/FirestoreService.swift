//
//  FirestoreService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/6/24.
//


import FirebaseFirestore
import FirebaseStorage
import GooglePlaces

class FirestoreService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func fetchPhotosFromStorage(placeId: String, returnFirstImageOnly: Bool = false, completion: @escaping ([UIImage]?, Error?) -> Void) {
        let storageRef = storage.reference().child("reviews/\(placeId)")
        
        storageRef.listAll { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error listing files in storage for place \(placeId): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let result = result else {
                print("No result returned for storage path reviews/\(placeId)")
                completion([], nil)
                return
            }
            
            var images: [UIImage] = []
            let dispatchGroup = DispatchGroup()
            
            let itemsToProcess = returnFirstImageOnly ? result.items.prefix(1) : result.items.prefix(9)
            
            for item in itemsToProcess { // Limit to 1 if returnFirstImageOnly, otherwise max 9
                dispatchGroup.enter()
                
                item.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    defer { dispatchGroup.leave() }
                    
                    if let error = error {
                        print("Error downloading image \(item.name): \(error.localizedDescription)")
                        return
                    }
                    
                    if let data = data, let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(images, nil)
            }
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
    
    func fetchReviews(placeId: String, completion: @escaping ([Review]?, Error?) -> Void) {
        // Reference to the reviews subcollection under the place document
        let reviewsRef = db.collection("places")
                          .document(placeId)
                          .collection("reviews")
        
        // Fetch all documents in the reviews collection
        reviewsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot else {
                print("No snapshot returned for reviews of place \(placeId)")
                completion([], nil)
                return
            }
            
            // Decode each document into a Review object
            let reviews: [Review] = snapshot.documents.compactMap { document in
                try? document.data(as: Review.self)
            }
            
            completion(reviews, nil)
        }
    }

    func fetchFriends(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        db.collection("following")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    completion([], nil)
                    return
                }
                
                let followingIds = snapshot.documents.compactMap { document in
                    document.get("followingId") as? String
                }
                
                completion(followingIds, nil)
            }
    }
    
    func fetchProfiles(for userIds: [String], completion: @escaping ([User]?, Error?) -> Void) {
        var profiles: [User] = []
        let dispatchGroup = DispatchGroup()
        
        for userId in userIds {
            dispatchGroup.enter()
            db.collection("users").document(userId).getDocument { document, error in
                if let error = error {
                    print("Error fetching user \(userId): \(error.localizedDescription)")
                    dispatchGroup.leave()
                    return
                }
                
                guard let document = document, document.exists else {
                    print("User \(userId) not found")
                    dispatchGroup.leave()
                    return
                }
                
                do {
                    let user = try document.data(as: User.self)
                    profiles.append(user)
                } catch {
                    print("Error decoding user \(userId): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(profiles, nil)
        }
    }
    
    func fetchFollowingProfiles(for userId: String, completion: @escaping ([User]?, Error?) -> Void) {
        fetchFriends(userId: userId) { followingIds, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let followingIds = followingIds, !followingIds.isEmpty else {
                completion([], nil)
                return
            }
            
            self.fetchProfiles(for: followingIds, completion: completion)
        }
    }
    func getNumberFollowers(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        db.collection("followers")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(0, error) // Return 0 followers and the error
                    return
                }
                
                // If no error, count the documents in the snapshot
                guard let snapshot = snapshot else {
                    completion(0, nil) // No documents, no error
                    return
                }
                
                let followerCount = snapshot.documents.count
                completion(followerCount, nil) // Return the count and no error
            }
    }
    
    func followUser(followerId: String, followingId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Create the follow relationship
        let follow = Follow(followerId: followerId, followingId: followingId, followedAt: Date())
        
        // Generate document IDs for the two separate collections
        let followingDocId = "\(followerId)_\(followingId)" // For the outgoing relationship
        let followersDocId = "\(followingId)_\(followerId)" // For the incoming relationship

        // References to the two collections
        let followingRef = db.collection("following").document(followingDocId)
        let followersRef = db.collection("followers").document(followersDocId)
        
        do {
            // First, add the document to the "following" collection
            try followingRef.setData(from: follow) { error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                // Then, add the document to the "followers" collection
                do {
                    try followersRef.setData(from: follow) { error in
                        completion(error == nil, error)
                    }
                } catch let error {
                    completion(false, error)
                }
            }
        } catch let error {
            completion(false, error)
        }
    }
    
    func unfollowUser(followerId: String, followingId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Generate the same document IDs as when following
        let followingDocId = "\(followerId)_\(followingId)"
        let followersDocId = "\(followingId)_\(followerId)"
        
        // References to the two collections
        let followingRef = db.collection("following").document(followingDocId)
        let followersRef = db.collection("followers").document(followersDocId)
        
        // Delete from the "following" collection first
        followingRef.delete { error in
            if let error = error {
                completion(false, error)
                return
            }
            // Then delete from the "followers" collection
            followersRef.delete { error in
                completion(error == nil, error)
            }
        }
    }

    func isFollowingUser(followerId: String, followingId: String, completion: @escaping (Bool) -> Void) {
        let followId = "\(followerId)_\(followingId)"
        let followRef = db.collection("following").document(followId)

        followRef.getDocument { document, error in
            if let document = document, document.exists {
                completion(true) // User is following
            } else {
                completion(false) // User is not following
            }
        }
    }

    func searchUsers(query: String, completion: @escaping ([ProfileData]?, Error?) -> Void) {
        let usersRef = db.collection("users")
        
        // Perform a name search using Firestore's `whereField` with `>=` and `<=` for simple prefix matching
        usersRef.whereField("fullName", isGreaterThanOrEqualTo: query)
                .whereField("fullName", isLessThanOrEqualTo: query + "\u{f8ff}")
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(nil, error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        completion([], nil)
                        return
                    }

                    let users: [ProfileData] = documents.compactMap { doc in
                        try? doc.data(as: ProfileData.self)
                    }

                    completion(users, nil)
                }
    }
    
    func saveReviewWithImages(
        review: Review,
        images: [UIImage],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 1) Upload images first
        uploadImagesForReview(review: review, images: images) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let downloadURLs):
                // 2) Update the review to include the new image URLs
                var updatedReview = review
                updatedReview.images = downloadURLs
                
                // 3) Save the updated review to Firestore
                self.saveReview(updatedReview) { saveResult in
                    switch saveResult {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                // If image upload fails, return the error
                completion(.failure(error))
            }
        }
    }


    func saveReview(_ review: Review, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Build a reference: places/{placeId}/reviews/{reviewId}
        let docRef = db.collection("places")
                       .document(review.placeId)
                       .collection("reviews")
                       .document(review.id)
        
        // 2. Encode the `Review` directly via setData(from:)
        do {
            try docRef.setData(from: review) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func uploadImagesForReview(
        review: Review,
        images: [UIImage],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        // If there are no images, return immediately with an empty array
        guard !images.isEmpty else {
            completion(.success([]))
            return
        }
        
        var downloadURLs: [String] = []
        var errors: [Error] = []

        // A DispatchGroup to wait for all uploads
        let dispatchGroup = DispatchGroup()
        
        for image in images {
            dispatchGroup.enter()
            
            // 1. Generate a unique name for each image
            let imageName = UUID().uuidString
            
            // 2. (Optional) Decide on a path for storing your review images
            //    For example: "reviews/{reviewId}/{imageName}.jpg"
            let storageRef = storage.reference()
                .child("reviews/\(review.id)/\(imageName).jpg")
            
            // 3. Convert the UIImage to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                errors.append(
                    NSError(domain: "FirestoreService", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: "Could not convert image to data"
                    ])
                )
                dispatchGroup.leave()
                continue
            }

            // 4. Upload the image data
            storageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    errors.append(error)
                    dispatchGroup.leave()
                    return
                }
                
                // 5. Once uploaded, fetch the download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        errors.append(error)
                    } else if let downloadURL = url {
                        downloadURLs.append(downloadURL.absoluteString)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // 6. When all uploads finish, call completion
        dispatchGroup.notify(queue: .main) {
            if let firstError = errors.first {
                completion(.failure(firstError))
            } else {
                completion(.success(downloadURLs))
            }
        }
    }




    // Function to upload an image and update the PlaceList's image field
    func uploadImageAndUpdatePlaceList(userId: String, placeList: PlaceList, image: UIImage, completion: @escaping (Error?) -> Void) {
        // 1. Generate a unique name for the image
        let imageName = UUID().uuidString
        let storageRef = storage.reference().child("placeListPhotos/\(userId)/\(placeList.name)/\(imageName)")

        // 2. Convert the UIImage to data (e.g., JPEG)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(NSError(domain: "FirestoreService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to data"]))
            return
        }

        // 3. Upload the image data to Firebase Storage
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(error)
                return
            }

            // 4. Get the download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(error)
                    return
                }

                guard let downloadURL = url else {
                    completion(NSError(domain: "FirestoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download URL was nil"]))
                    return
                }

                // 5. Update the PlaceList document in Firestore
                let placeListRef = self.db.collection("users").document(userId).collection("placeLists").document(placeList.name)
                placeListRef.updateData([
                    "image": downloadURL.absoluteString
                ]) { error in
                    completion(error)
                }
            }
        }
    }
    
    func saveUserProfile(uid: String, profileData: ProfileData, completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("users").document(uid)
                .setData(from: profileData, merge: true, completion: completion)
        } catch {
            completion(error)
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
    
    func removePlaceFromList(userId: String, listName: String, placeId: String) {
        db.collection("users").document(userId)
            .collection("placeLists").document(listName)
            .updateData(["places": FieldValue.arrayRemove([placeId])]) { error in
                if let error = error {
                    print("Error removing place from list: \(error.localizedDescription)")
                } else {
                    print("Place successfully removed from list: \(listName)")
                    
                    self.removeUserFromMapPlace(userId: userId, placeId: placeId) { success, error in
                           if let error = error {
                               print("Error removing user from mapPlace: \(error.localizedDescription)")
                           } else {
                               print("User successfully removed from mapPlace.")
                           }
                       }
                }
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
    
    func deleteList(userId: String, listName: String, completion: @escaping (Error?) -> Void) {
        let listRef = db.collection("users").document(userId)
                        .collection("placeLists").document(listName)
        
        listRef.delete { error in
            if let error = error {
                print("Error deleting list '\(listName)': \(error.localizedDescription)")
            } else {
                print("List successfully deleted: \(listName)")
            }
            completion(error)
        }
    }
    
    
    func fetchList(userId: String, listName: String, completion: @escaping (Result<PlaceList, Error>) -> Void) {
        db.collection("users").document(userId)
            .collection("placeLists").document(listName)
            .getDocument { document, error in
                if let error = error {
                    print("Error fetching list: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let document = document, document.exists else {
                    let notFoundError = NSError(domain: "FirestoreError", code: 404, userInfo: [NSLocalizedDescriptionKey: "List not found"])
                    completion(.failure(notFoundError))
                    return
                }

                do {
                    let placeList = try document.data(as: PlaceList.self)
                    completion(.success(placeList))
                } catch {
                    print("Error decoding list: \(error.localizedDescription)")
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
                    print("Document count: \(result?.documents.count ?? 0)")
                    let placeLists = result?.documents.compactMap { document in
                        try? document.data(as: PlaceList.self)
                    } ?? []
                    completion(placeLists) // Return the fetched place lists
                }
            }
    }
    
    func addProfileFavorite(userId: String, place: DetailPlace) {
        
        do {
            try db.collection("users")
                .document(userId)
                .collection("favorites")
                .document(place.id.uuidString)
                .setData(from: place) { error in
                    if let error = error {
                        print("Error adding place to favorites: \(error.localizedDescription)")
                    } else {
                        print("Place successfully added to favorites")
                    }
                }
            addOrUpdateMapPlace(for: userId, place: place, type: "favorite")
        } catch {
            print("Error encoding place: \(error.localizedDescription)")
        }
    }
    
    func addOrUpdateMapPlace(for userId: String, place: DetailPlace, type: String, listId: String? = nil) {
        // Create the MapPlaceUserInfo for the new entry.
        let userInfo = MapPlaceUserInfo(
            userId: userId,
            type: type,
            listId: listId,
            addedAt: Date()
        )
        
        // Prepare a reference to the mapPlaces collection. Assume we use place.id as the document ID.
        let mapPlaceRef = db.collection("mapPlaces").document(place.id.uuidString)
        
        // Attempt to get the existing document.
        mapPlaceRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // The place already exists. Update the 'addedBy' field.
                do {
                    // Decode the existing MapPlace.
                    var existingMapPlace = try document.data(as: MapPlace.self)
                    // Append the new user info.
                    existingMapPlace.addedBy[userId] = userInfo
                    // Save the updated document.
                    try mapPlaceRef.setData(from: existingMapPlace) { error in
                        if let error = error {
                            print("Error updating map place: \(error.localizedDescription)")
                        } else {
                            print("Successfully updated map place with new user info.")
                        }
                    }
                } catch {
                    print("Error decoding existing MapPlace: \(error.localizedDescription)")
                }
            } else {
                // The place does not exist yet. Create a new MapPlace document.
                let newMapPlace = MapPlace(
                    placeId: place.id.uuidString,
                    name: place.name,
                    address: place.address,
                    addedBy: [userId: userInfo]
                ) 
                do {
                    try mapPlaceRef.setData(from: newMapPlace) { error in
                        if let error = error {
                            print("Error creating new map place: \(error.localizedDescription)")
                        } else {
                            print("Successfully created new map place.")
                        }
                    }
                } catch {
                    print("Error encoding new MapPlace: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func removeProfileFavorite(userId: String, placeId: String) {
        // Reference to the user's favorites collection.
        let favoritesRef = db.collection("users")
            .document(userId)
            .collection("favorites")
            .document(placeId)
        
        // Delete the document from the user's favorites collection.
        favoritesRef.delete { error in
            if let error = error {
                print("Error removing favorite place from user's collection: \(error.localizedDescription)")
            } else {
                print("Favorite place successfully removed from user's collection.")
                // Now remove the user's association from the aggregated mapPlaces document.
                self.removeUserFromMapPlace(userId: userId, placeId: placeId) { success, error in
                    if let error = error {
                        print("Error removing user from mapPlace: \(error.localizedDescription)")
                    } else {
                        print("User successfully removed from mapPlace.")
                    }
                }
            }
        }
    }
    
    func removeUserFromMapPlace(userId: String, placeId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Reference to the mapPlaces document for the given place.
        let mapPlaceRef = db.collection("mapPlaces").document(placeId)
        
        // Update the document by removing the entry for the user from the addedBy dictionary.
        mapPlaceRef.updateData([
            "addedBy.\(userId)": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("Error removing user from mapPlace: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("User successfully removed from mapPlace.")
                completion(true, nil)
            }
        }
    }

    
    func fetchProfileFavorites(userId: String, completion: @escaping ([DetailPlace]?) -> Void) {
        db.collection("users")
            .document(userId)
            .collection("favorites")
            .getDocuments { snapshot, error in
                
                if let error = error {
                    print("Error fetching favorites: \(error.localizedDescription)")
                    completion([])
                } else {
                    // Attempt to decode each document into a DetailPlace
                    let detailPlaces = snapshot?.documents.compactMap {
                        try? $0.data(as: DetailPlace.self)
                    } ?? []
                    
                    completion(detailPlaces)
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
}
