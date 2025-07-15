import Foundation
import Firebase

class UserService: ObservableObject {
    static let shared = UserService()
    private let db = FirebaseManager.shared.db
    
    private init() {}

    func fetchUser(userId: String, completion: @escaping (User?, Error?) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let document = document, document.exists else {
                completion(nil, nil) // User not found, no error
                return
            }
            
            do {
                let user = try document.data(as: User.self)
                completion(user, nil)
            } catch {
                completion(nil, error)
            }
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
    
    func fetchFollowerProfiles(for userId: String, completion: @escaping ([User]?, Error?) -> Void) {
        // First get the IDs of users who follow this user
        db.collection("followers")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    completion([], nil)
                    return
                }
                
                let followerIds = snapshot.documents.compactMap { document in
                    document.get("followerId") as? String
                }
                
                guard !followerIds.isEmpty else {
                    completion([], nil)
                    return
                }
                
                // Then fetch the full profile for each follower ID
                self.fetchProfiles(for: followerIds, completion: completion)
            }
    }

    func fetchFollowingProfilesData(for userId: String, completion: @escaping ([ProfileData]?, Error?) -> Void) {
        fetchFriends(userId: userId) { followingIds, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let followingIds = followingIds, !followingIds.isEmpty else {
                completion([], nil)
                return
            }
            
            self.fetchProfilesData(for: followingIds, completion: completion)
        }
    }
    
    func fetchFollowerProfilesData(for userId: String, completion: @escaping ([ProfileData]?, Error?) -> Void) {
        // First get the IDs of users who follow this user
        db.collection("followers")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    completion([], nil)
                    return
                }
                
                let followerIds = snapshot.documents.compactMap { document in
                    document.get("followerId") as? String
                }
                
                guard !followerIds.isEmpty else {
                    completion([], nil)
                    return
                }
                
                // Then fetch the full profile for each follower ID
                self.fetchProfilesData(for: followerIds, completion: completion)
            }
    }

    func fetchProfilesData(for userIds: [String], completion: @escaping ([ProfileData]?, Error?) -> Void) {
        var profiles: [ProfileData] = []
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
                    let profile = try document.data(as: ProfileData.self)
                    profiles.append(profile)
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
    func getNumberFollowing(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        db.collection("following")
            .whereField("followerId", isEqualTo: userId)
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
                
                let followingCount = snapshot.documents.count
                completion(followingCount, nil) // Return the count and no error
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
        let queryLower = query.lowercased()
        
        // Perform a name search using Firestore's `whereField` with `>=` and `<=` for simple prefix matching
        usersRef.whereField("fullNameLower", isGreaterThanOrEqualTo: queryLower)
                .whereField("fullNameLower", isLessThanOrEqualTo: queryLower + "\u{f8ff}")
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

    func saveUserProfile(uid: String, profileData: ProfileData, completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("users").document(uid)
                .setData(from: profileData, merge: true, completion: completion)
        } catch {
            completion(error)
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

    func fetchUserReviewPlaces(userId: String, user: User, completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        // Reference to the user's reviews collection
        let reviewsRef = db.collection("users")
                          .document(userId)
                          .collection("reviews")
        
        reviewsRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching reviews for user \(userId): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot else {
                print("No reviews found for user \(userId)")
                completion([], nil)
                return
            }
            
            // Get all reviews and their placeIds
            let reviews = snapshot.documents.compactMap { document in
                try? document.data(as: RestaurantReview.self)
            }
            
            let placeIds = Set(reviews.map { $0.placeId })
            
            // If no places found in reviews
            if placeIds.isEmpty {
                completion([], nil)
                return
            }
            
            var allPlaces: [DetailPlace] = []
            let dispatchGroup = DispatchGroup()
            var firstError: Error?
            
            let placesRef = db.collection("places")
            let placeIdsArray = Array(placeIds)
            let chunkSize = 30
            let chunks = stride(from: 0, to: placeIdsArray.count, by: chunkSize).map {
                Array(placeIdsArray[$0..<min($0 + chunkSize, placeIdsArray.count)])
            }
            
            print("Fetching place details for \(placeIdsArray.count) review places in \(chunks.count) chunks...")
            
            // Fetch details for each chunk
            for chunk in chunks {
                dispatchGroup.enter()
                placesRef.whereField("id", in: chunk).getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching place chunk: \(error.localizedDescription)")
                        if firstError == nil { firstError = error } // Capture first error
                        dispatchGroup.leave()
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        print("No places found for a chunk")
                        dispatchGroup.leave()
                        return
                    }
                    
                    // Decode places from the current chunk
                    let chunkPlaces = snapshot.documents.compactMap { try? $0.data(as: DetailPlace.self) }
                    
                    // --- Concurrently fetch Mapbox details if needed (Removed for simplicity based on previous code) ---
                    // The original code seemed to fetch Firestore places first, then Mapbox places based on mapboxId.
                    // If you need full GMSPlace/Mapbox data, further fetching based on mapboxId would be needed here.
                    // For now, we assume the DetailPlace from Firestore is sufficient.
                    // -------------------------------------------------------------------------------------------
                    
                    // Append places from this chunk
                    // Use DispatchQueue.main if you need to update UI immediately, otherwise append directly
                    DispatchQueue.main.async { // Or sync queue if preferred
                        allPlaces.append(contentsOf: chunkPlaces)
                        dispatchGroup.leave()
                    }
                }
            }
            
            // Notify when all chunks are processed
            dispatchGroup.notify(queue: .main) {
                if let error = firstError {
                    completion(nil, error) // Return the first error encountered
                } else {
                    print("Successfully fetched details for \(allPlaces.count) review places.")
                    completion(allPlaces, nil)
                }
            }
        }
    }

    func fetchUserById(userId: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                let notFoundError = NSError(domain: "FirestoreService", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "User not found"
                ])
                completion(.failure(notFoundError))
                return
            }
            
            do {
                let profileData = try document.data(as: ProfileData.self)
                completion(.success(profileData))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // New implementation that avoids EXC_BAD_ACCESS
    func fetchFriendsReviews(placeId: String, currentUserId: String, completion: @escaping ([ReviewProtocol]?, Error?) -> Void) {
        // Step 1: Get list of users the current user follows
        fetchFriends(userId: currentUserId) { [weak self] followingIds, error in
            guard let self = self else { 
                completion(nil, NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"]))
                return 
            }
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Handle case where user doesn't follow anyone or error occurred
            guard let followingIds = followingIds, !followingIds.isEmpty else {
                completion([], nil)
                return
            }
            
            // Always include the current user's own reviews
            var userIdsToFetch = Set(followingIds)
            userIdsToFetch.insert(currentUserId)
            
            // Step 2: Fetch all reviews for the place
            let reviewsRef = self.db.collection("places")
                             .document(placeId)
                             .collection("reviews")
            
            reviewsRef.order(by: "timestamp", descending: true).getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    completion([], nil)
                    return
                }
                
                // Step 3: Filter reviews to only those from followed users and the current user
                // Use concrete types first to avoid memory issues
                var restaurantReviews: [RestaurantReview] = []
                var genericReviews: [GenericReview] = []
                
                for document in snapshot.documents {
                    let data = document.data()
                    
                    // First check if the review is from a user we want to include
                    guard let userId = data["userId"] as? String,
                          userIdsToFetch.contains(userId) else {
                        continue // Skip reviews from users we don't follow
                    }
                    
                    // Check the type field to determine how to decode
                    if let typeString = data["type"] as? String,
                       let type = ReviewType(rawValue: typeString) {
                        
                        switch type {
                        case .restaurant:
                            if let restaurantReview = try? document.data(as: RestaurantReview.self) {
                                restaurantReviews.append(restaurantReview)
                            }
                        case .generic:
                            if let genericReview = try? document.data(as: GenericReview.self) {
                                genericReviews.append(genericReview)
                            }
                        }
                    } else {
                        // Fallback to trying both types if type field is missing
                        if let restaurantReview = try? document.data(as: RestaurantReview.self) {
                            restaurantReviews.append(restaurantReview)
                        } else if let genericReview = try? document.data(as: GenericReview.self) {
                            genericReviews.append(genericReview)
                        }
                    }
                }
                
                // Client-side sort by timestamp to ensure correct order
                var allReviewsUnsorted: [ReviewProtocol] = []
                for review in restaurantReviews {
                    allReviewsUnsorted.append(review as ReviewProtocol)
                }
                for review in genericReviews {
                    allReviewsUnsorted.append(review as ReviewProtocol)
                }
                let allReviewsSorted = allReviewsUnsorted.sorted { $0.timestamp > $1.timestamp }
                // Ensure we're on the main thread when calling the completion handler
                DispatchQueue.main.async {
                    completion(allReviewsSorted, nil)
                }
            }
        }
    }

    func fetchUserById(userId: String) async throws -> ProfileData {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchUserById(userId: userId) { result in
                switch result {
                case .success(let profileData):
                    continuation.resume(returning: profileData)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchFollowingProfilesData(for userId: String) async throws -> [ProfileData] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchFollowingProfilesData(for: userId) { profiles, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: profiles ?? [])
                }
            }
        }
    }
    
    func fetchFollowerProfilesData(for userId: String) async throws -> [ProfileData] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchFollowerProfilesData(for: userId) { profiles, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: profiles ?? [])
                }
            }
        }
    }

    func getNumberFollowers(forUserId userId: String) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            self.getNumberFollowers(forUserId: userId) { count, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: count)
                }
            }
        }
    }
    
    func getNumberFollowing(forUserId userId: String) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            self.getNumberFollowing(forUserId: userId) { count, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: count)
                }
            }
        }
    }

    
    
    // MARK: - User Profile
    // Functions like fetchUser, saveUserProfile, fetchUserById, searchUsers, updateProfilePictureInUserReviews will go here.
    
    // MARK: - Following
    // Functions like followUser, unfollowUser, isFollowingUser, fetchFriends, fetchFollowingProfiles, fetchFollowerProfiles, getNumberFollowers, getNumberFollowing will go here.
    
    // MARK: - FCM Token
    // Functions like updateFCMToken, getFCMTokens will go here.
    func updateFCMToken(userId: String, token: String, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        userRef.updateData([
            "fcmToken": token
        ]) { error in
            completion(error)
        }
    }
    
    func getFCMTokens(for userIds: [String], completion: @escaping ([String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([])
            return
        }
        
        // Firestore 'in' queries are limited to 30 items at a time, but 10 is safer
        let chunks = userIds.chunked(into: 10)
        var allTokens: [String] = []
        let dispatchGroup = DispatchGroup()
        
        for chunk in chunks {
            dispatchGroup.enter()
            db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching FCM tokens: \(error)")
                        dispatchGroup.leave()
                        return
                    }
                    
                    let tokens = snapshot?.documents.compactMap { document in
                        document.get("fcmToken") as? String
                    } ?? []
                    
                    allTokens.append(contentsOf: tokens)
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(allTokens)
        }
    }
    
    // MARK: - External Places (TikTok-sourced places)
    
    /// Fetch user's external places and return them as a dictionary keyed by placeId
    func fetchUserExternalPlaces(userId: String, completion: @escaping ([String: ExternalPlace]?, Error?) -> Void) {
        print("🔍 Fetching external places for user: \(userId)")
        
        let externalPlacesRef = db.collection("users")
            .document(userId)
            .collection("externalPlaces")
        
        externalPlacesRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching external places for user \(userId): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot else {
                print("⚠️ No snapshot returned for external places of user \(userId)")
                completion([:], nil)
                return
            }
            
            var externalPlacesDictionary: [String: ExternalPlace] = [:]
            
            for document in snapshot.documents {
                do {
                    var externalPlace = try document.data(as: ExternalPlace.self)
                    
                    // Set the document ID manually since it won't be in the document data
                    externalPlace = ExternalPlace(
                        id: document.documentID,
                        addedAt: externalPlace.addedAt,
                        address: externalPlace.address,
                        coordinates: externalPlace.coordinates,
                        name: externalPlace.name,
                        placeId: externalPlace.placeId,
                        source: externalPlace.source,
                        tiktokVideos: externalPlace.tiktokVideos
                    )
                    
                    // Use placeId as the key for the dictionary
                    externalPlacesDictionary[externalPlace.placeId] = externalPlace
                    
                } catch {
                    print("❌ Error decoding external place document \(document.documentID): \(error.localizedDescription)")
                    // Continue processing other documents even if one fails
                }
            }
            
            print("✅ Successfully fetched \(externalPlacesDictionary.count) external places for user \(userId)")
            completion(externalPlacesDictionary, nil)
        }
    }
    
    /// Async version of fetchUserExternalPlaces
    func fetchUserExternalPlaces(userId: String) async throws -> [String: ExternalPlace] {
        try await withCheckedThrowingContinuation { continuation in
            fetchUserExternalPlaces(userId: userId) { externalPlaces, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: externalPlaces ?? [:])
                }
            }
        }
    }
} 
