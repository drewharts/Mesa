//
//  FirestoreService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/6/24.
//


import FirebaseFirestore
import FirebaseStorage
import UIKit

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func updateProfilePhoto(userId: String, image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        // Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            let error = NSError(domain: "ProfileFirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
            completion(.failure(error))
            return
        }
        
        // Create a unique filename
        let filename = "profile_photos/\(userId)_\(Date().timeIntervalSince1970).jpg"
        let storageRef = storage.reference().child(filename)
        
        // Upload the image data
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // First, check if user has an existing profile photo
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error checking existing profile photo: \(error.localizedDescription)")
                // Continue with upload even if we can't check existing photo
            }
            
            // Try to delete existing photo if it exists
            if let existingPhotoURL = document?.data()?["profilePhotoURL"] as? String {
                // Extract the filename from the URL
                if let existingPhotoPath = existingPhotoURL.components(separatedBy: "/").last {
                    let existingRef = self.storage.reference().child("profile_photos/\(existingPhotoPath)")
                    existingRef.delete { error in
                        if let error = error {
                            // Only log the error if it's not a "not found" error
                            if (error as NSError).domain != "com.google.HTTPStatus" || (error as NSError).code != 404 {
                                print("Error deleting existing profile photo: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
            
            // Now upload the new photo
            storageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("Error uploading profile photo: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Wait a brief moment to ensure the upload is fully processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            print("Error getting download URL: \(error.localizedDescription)")
                            completion(.failure(error))
                            return
                        }
                        
                        guard let downloadURL = url else {
                            let error = NSError(domain: "ProfileFirestoreService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Download URL was nil"])
                            completion(.failure(error))
                            return
                        }
                        
                        // Update the user's profile document with the new URL
                        userRef.updateData([
                            "profilePhotoURL": downloadURL.absoluteString
                        ]) { error in
                            if let error = error {
                                print("Error updating user profile: \(error.localizedDescription)")
                                completion(.failure(error))
                            } else {
                                print("Successfully updated profile photo URL")
                                completion(.success(downloadURL))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Add async version of updateProfilePhoto
    func updateProfilePhoto(userId: String, image: UIImage) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            updateProfilePhoto(userId: userId, image: image) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
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

        // Update OpenHours for a specific place
        func updateOpenHours(for placeId: String, openHours: [String]?, completion: @escaping (Error?) -> Void) {
            let data: [String: Any] = ["OpenHours": openHours as Any]
            db.collection("places").document(placeId).updateData(data) { error in
                if let error = error {
                    print("Error updating OpenHours for place \(placeId): \(error.localizedDescription)")
                } else {
                    print("Successfully updated OpenHours for place \(placeId)")
                }
                completion(error)
            }
        }
    
    func addFieldToAllPlaces(fieldName: String, fieldValue: Any) {
        let db = Firestore.firestore()

        db.collection("places").getDocuments { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    // Update each document with the new field
                    db.collection("places").document(document.documentID).updateData([
                        fieldName: fieldValue
                    ]) { err in
                        if let err = err {
                            print("Error updating document: \(err)")
                        } else {
                            print("Document updated!")
                        }
                    }
                }
            }
        }
    }

    
    func fetchCurrentUser(userId: String, completion: @escaping (User?, Error?) -> Void) {
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
    
    func fetchPhotosFromStorage(urls: [String], completion: @escaping ([UIImage]?, Error?) -> Void) {
        // Early exit for empty URLs
        guard !urls.isEmpty else {
            DispatchQueue.main.async {
                completion([], nil)
            }
            return
        }
        
        var images: [UIImage] = []
        let group = DispatchGroup()
        var lastError: Error?
        
        // Use OperationQueue to limit concurrent downloads
        let downloadQueue = OperationQueue()
        downloadQueue.maxConcurrentOperationCount = 3 // Limit concurrent downloads
        
        for urlString in urls {
            // Skip invalid URLs
            guard let url = URL(string: urlString) else {
                print("Invalid URL: \(urlString)")
                continue
            }
            
            // Check cache first
            if let cachedImage = ImageCacheService.shared.getImage(for: url) {
                images.append(cachedImage)
                continue
            }
            
            group.enter()
            
            // Create download operation
            let operation = BlockOperation {
                // Create a semaphore to handle the async task within the operation
                let semaphore = DispatchSemaphore(value: 0)
                
                var retryCount = 0
                let maxRetries = 2
                
                func attemptDownload() {
                    // Configure the URLRequest with timeout
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 15 // 15 seconds timeout
                    
                    URLSession.shared.dataTask(with: request) { data, response, error in
                        // Handle error with retry logic
                        if let error = error {
                            if retryCount < maxRetries {
                                retryCount += 1
                                print("Retry \(retryCount) for URL: \(urlString)")
                                attemptDownload() // Recursive retry
                                return
                            }
                            
                            print("Error downloading image after \(maxRetries) retries from \(urlString): \(error.localizedDescription)")
                            lastError = error
                            semaphore.signal()
                            group.leave()
                            return
                        }
                        
                        // Process image data
                        if let data = data {
                            // Check for image data size and possibly downsample for large images
                            if data.count > 1024 * 1024 { // If larger than 1MB
                                if let downsampledImage = self.downsampleImage(data: data, to: CGSize(width: 1000, height: 1000)) {
                                    images.append(downsampledImage)
                                    ImageCacheService.shared.storeImage(downsampledImage, for: url)
                                } else if let image = UIImage(data: data) {
                                    images.append(image)
                                    ImageCacheService.shared.storeImage(image, for: url)
                                }
                            } else if let image = UIImage(data: data) {
                                images.append(image)
                                ImageCacheService.shared.storeImage(image, for: url)
                            }
                        }
                        
                        semaphore.signal()
                        group.leave()
                    }.resume()
                }
                
                // Start the download process
                attemptDownload()
                
                // Wait for the async operation to complete
                semaphore.wait()
            }
            
            downloadQueue.addOperation(operation)
        }
        
        // Handle completion
        group.notify(queue: .main) {
            if images.isEmpty && lastError != nil {
                completion(nil, lastError)
            } else {
                completion(images, nil)
            }
        }
    }
    
    // Helper method to downsample large images
    private func downsampleImage(data: Data, to pointSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * UIScreen.main.scale
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
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
                
                let itemsToProcess = returnFirstImageOnly ? result.items.prefix(1) : result.items.prefix(9)
                let itemsArray = Array(itemsToProcess) // Convert to array for indexing
                var images: [UIImage] = []
                var lastError: Error? = nil
                
                // Recursive function to fetch images one by one
                func fetchNextImage(index: Int) {
                    // Base case: all items processed
                    if index >= itemsArray.count {
                        DispatchQueue.main.async {
                            completion(images.isEmpty && lastError == nil ? [] : images, lastError)
                        }
                        return
                    }
                    
                    let item = itemsArray[index]
                    item.getData(maxSize: 5 * 1024 * 1024) { data, error in
                        if let error = error {
                            print("Error downloading image \(item.name): \(error.localizedDescription)")
                            lastError = error
                        } else if let data = data, let image = UIImage(data: data) {
                            images.append(image)
                        }
                        
                        // Fetch the next image
                        fetchNextImage(index: index + 1)
                    }
                }
                
                // Start fetching from the first item
                fetchNextImage(index: 0)
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
    
    func fetchReviews<T: ReviewProtocol>(placeId: String, latestOnly: Bool = false, completion: @escaping ([T]?, Error?) -> Void) {
        // Reference to the reviews subcollection under the place document
        let reviewsRef = db.collection("places")
                         .document(placeId)
                         .collection("reviews")
        
        // Create the query based on the latestOnly flag
        let query = latestOnly ?
            reviewsRef.order(by: "timestamp", descending: true).limit(to: 1) : // Latest review only
            reviewsRef.order(by: "timestamp", descending: false)              // All reviews
        
        // Fetch documents based on the query
        query.getDocuments { snapshot, error in
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
            
            // Decode each document into the appropriate Review type
            let reviews: [T] = snapshot.documents.compactMap { document in
                try? document.data(as: T.self)
            }
            
            completion(reviews, nil)
        }
    }

    // Convenience method for backward compatibility
    func fetchReviews(placeId: String, latestOnly: Bool = false, completion: @escaping ([RestaurantReview]?, Error?) -> Void) {
        fetchReviews(placeId: placeId, latestOnly: latestOnly, completion: completion)
    }

    func fetchFriends(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        print("🔍 DEBUG: Starting fetchFriends for userId: \(userId)")
        
        db.collection("following")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ DEBUG: Error fetching following list: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ DEBUG: No snapshot returned for following list")
                    completion([], nil)
                    return
                }
                
                print("✅ DEBUG: Found \(snapshot.documents.count) following relationships")
                
                let followingIds = snapshot.documents.compactMap { document in
                    let followingId = document.get("followingId") as? String
                    if followingId == nil {
                        print("⚠️ DEBUG: Document missing followingId: \(document.documentID)")
                    }
                    return followingId
                }
                
                print("✅ DEBUG: Extracted \(followingIds.count) following IDs: \(followingIds)")
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
    
    func saveReviewWithImages<T: ReviewProtocol>(
        review: T,
        images: [UIImage],
        completion: @escaping (Result<T, Error>) -> Void
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
                        // Return the updated review instead of Void
                        completion(.success(updatedReview))
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


    func saveReview<T: ReviewProtocol>(_ review: T, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Build references for both locations
        let placeReviewRef = db.collection("places")
                              .document(review.placeId)
                              .collection("reviews")
                              .document(review.id)
        
        let userReviewRef = db.collection("users")
                             .document(review.userId)
                             .collection("reviews")
                             .document(review.id)
        
        // 2. Encode the Review
        do {
            let reviewData = try Firestore.Encoder().encode(review)
            
            // 3. Use a batch write to save to both locations atomically
            let batch = db.batch()
            batch.setData(reviewData, forDocument: placeReviewRef)
            batch.setData(reviewData, forDocument: userReviewRef)
            
            batch.commit { error in
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
    
    func uploadImagesForReview<T: ReviewProtocol>(
        review: T,
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
            guard let imageData = image.jpegData(compressionQuality: 0.5) else {
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

    func likeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let reviewRef = db.collection("places").document(placeId).collection("reviews").document(reviewId)
        let likeRef = db.collection("reviewLikes").document("\(userId)_\(reviewId)")
        
        // Use a transaction to handle both the like count and the like record
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // First check if user has already liked
            let likeDocument: DocumentSnapshot
            do {
                try likeDocument = transaction.getDocument(likeRef)
                if likeDocument.exists {
                    let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "User has already liked this review"
                    ])
                    errorPointer?.pointee = error
                    return nil
                }
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Then get the review and increment likes
            let reviewDocument: DocumentSnapshot
            do {
                try reviewDocument = transaction.getDocument(reviewRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let oldLikes = reviewDocument.data()?["likes"] as? Int else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to retrieve likes count"
                ])
                errorPointer?.pointee = error
                return nil
            }
            
            // Create the like record
            let likeData: [String: Any] = [
                "userId": userId,
                "reviewId": reviewId,
                "placeId": placeId,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            // Update both documents in the transaction
            transaction.setData(likeData, forDocument: likeRef)
            transaction.updateData(["likes": oldLikes + 1], forDocument: reviewRef)
            
            return nil
        }) { (_, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func unlikeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let reviewRef = db.collection("places").document(placeId).collection("reviews").document(reviewId)
        let likeRef = db.collection("reviewLikes").document("\(userId)_\(reviewId)")
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // First verify the like exists
            let likeDocument: DocumentSnapshot
            do {
                try likeDocument = transaction.getDocument(likeRef)
                if !likeDocument.exists {
                    let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "User has not liked this review"
                    ])
                    errorPointer?.pointee = error
                    return nil
                }
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Then get the review and decrement likes
            let reviewDocument: DocumentSnapshot
            do {
                try reviewDocument = transaction.getDocument(reviewRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let oldLikes = reviewDocument.data()?["likes"] as? Int else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to retrieve likes count"
                ])
                errorPointer?.pointee = error
                return nil
            }
            
            // Delete the like record and decrement the count
            transaction.deleteDocument(likeRef)
            transaction.updateData(["likes": max(0, oldLikes - 1)], forDocument: reviewRef)
            
            return nil
        }) { (_, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func hasUserLikedReview(userId: String, reviewId: String, completion: @escaping (Bool) -> Void) {
        let likeRef = db.collection("reviewLikes").document("\(userId)_\(reviewId)")
        
        likeRef.getDocument { document, error in
            if let error = error {
                print("Error checking like status: \(error.localizedDescription)")
                completion(false)
                return
            }
            completion(document?.exists ?? false)
        }
    }

    func fetchUserReviews<T: ReviewProtocol>(userId: String, completion: @escaping ([T]?, Error?) -> Void) {
        // Reference to the user's reviews collection
        let reviewsRef = db.collection("users")
                          .document(userId)
                          .collection("reviews")
        
        // Query the reviews, ordered by timestamp descending (most recent first)
        reviewsRef.order(by: "timestamp", descending: true)
                 .getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching reviews for user \(userId): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot else {
                print("No snapshot returned for reviews of user \(userId)")
                completion([], nil)
                return
            }
            
            // Decode each document into the appropriate Review type
            let reviews: [T] = snapshot.documents.compactMap { document in
                try? document.data(as: T.self)
            }
            
            completion(reviews, nil)
        }
    }

    // Convenience method for backward compatibility
    func fetchUserReviews(userId: String, completion: @escaping ([RestaurantReview]?, Error?) -> Void) {
        fetchUserReviews(userId: userId, completion: completion)
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
            
            var places: [DetailPlace] = []
            let dispatchGroup = DispatchGroup()
            var fetchError: Error?
            
            // Fetch each unique place
            for placeId in placeIds {
                dispatchGroup.enter()
                
                self.fetchPlace(withId: placeId) { result in
                    switch result {
                    case .success(let place):
                        places.append(place)
                    case .failure(let error):
                        print("Error fetching place \(placeId): \(error.localizedDescription)")
                        fetchError = error
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if let error = fetchError {
                    completion(nil, error)
                } else {
                    completion(places, nil)
                }
            }
        }
    }

    func updateProfilePictureInUserReviews(userId: String, newProfilePictureURL: String, completion: @escaping (Error?) -> Void) {
        // Reference to the user's reviews collection
        let reviewsRef = db.collection("users")
                          .document(userId)
                          .collection("reviews")
        
        // Get all reviews for the user
        reviewsRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching user reviews: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No reviews found for user")
                completion(nil)
                return
            }
            
            let batch = self.db.batch()
            var batchCount = 0
            let maxBatchSize = 500 // Firestore batch limit
            
            for document in documents {
                let reviewRef = reviewsRef.document(document.documentID)
                batch.updateData(["profilePhotoUrl": newProfilePictureURL], forDocument: reviewRef)
                batchCount += 1
                
                // Commit batch when it reaches the limit
                if batchCount >= maxBatchSize {
                    batch.commit { error in
                        if let error = error {
                            print("Error updating batch of reviews: \(error.localizedDescription)")
                        }
                    }
                    batchCount = 0
                }
            }
            
            // Commit any remaining updates
            if batchCount > 0 {
                batch.commit { error in
                    if let error = error {
                        print("Error updating final batch of reviews: \(error.localizedDescription)")
                    }
                    completion(error)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    func updateProfilePictureInPlaceReviews(userId: String, newProfilePictureURL: String, completion: @escaping (Error?) -> Void) {
        // First, get all reviews from the user's collection
        let userReviewsRef = db.collection("users")
                              .document(userId)
                              .collection("reviews")
        
        userReviewsRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching user reviews: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No reviews found for user")
                completion(nil)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var updateError: Error?
            
            // Process reviews in batches
            let batchSize = 500
            var currentBatch = self.db.batch()
            var batchCount = 0
            
            for document in documents {
                guard let review = try? document.data(as: RestaurantReview.self) else { continue }
                
                // Get reference to the review in the place's collection
                let placeReviewRef = self.db.collection("places")
                                          .document(review.placeId)
                                          .collection("reviews")
                                          .document(review.id)
                
                // Update the review with new profile picture URL
                currentBatch.updateData([
                    "profilePhotoUrl": newProfilePictureURL,
                    "userFirstName": review.userFirstName,
                    "userLastName": review.userLastName
                ], forDocument: placeReviewRef)
                
                batchCount += 1
                
                // Commit batch when it reaches the limit
                if batchCount >= batchSize {
                    dispatchGroup.enter()
                    currentBatch.commit { error in
                        if let error = error {
                            print("Error updating batch of reviews: \(error.localizedDescription)")
                            updateError = error
                        }
                        dispatchGroup.leave()
                    }
                    currentBatch = self.db.batch()
                    batchCount = 0
                }
            }
            
            // Commit any remaining updates
            if batchCount > 0 {
                dispatchGroup.enter()
                currentBatch.commit { error in
                    if let error = error {
                        print("Error updating final batch of reviews: \(error.localizedDescription)")
                        updateError = error
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(updateError)
            }
        }
    }
    
    // Function to update profile picture across all reviews
    func updateProfilePictureAcrossAllReviews(userId: String, newProfilePictureURL: String, completion: @escaping (Error?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var updateError: Error?
        
        // Update user's reviews
        dispatchGroup.enter()
        updateProfilePictureInUserReviews(userId: userId, newProfilePictureURL: newProfilePictureURL) { error in
            if let error = error {
                print("Error updating user reviews: \(error.localizedDescription)")
                updateError = error
            }
            dispatchGroup.leave()
        }
        
        // Update place reviews
        dispatchGroup.enter()
        updateProfilePictureInPlaceReviews(userId: userId, newProfilePictureURL: newProfilePictureURL) { error in
            if let error = error {
                print("Error updating place reviews: \(error.localizedDescription)")
                updateError = error
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(updateError)
        }
    }
    
        // MARK: - Comment Methods
        
        func addComment(placeId: String, reviewId: String, comment: Comment, images: [UIImage], completion: @escaping (Result<Comment, Error>) -> Void) {
            // 1) Upload images first if any
            uploadImagesForComment(comment: comment, images: images) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let downloadURLs):
                    // 2) Update the comment to include the new image URLs
                    var updatedComment = comment
                    updatedComment.images = downloadURLs
                    
                    // 3) Save the updated comment to Firestore
                    self.saveComment(placeId: placeId, reviewId: reviewId, comment: updatedComment) { saveResult in
                        switch saveResult {
                        case .success:
                            // Return the updated comment
                            completion(.success(updatedComment))
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
        
        private func saveComment(placeId: String, reviewId: String, comment: Comment, completion: @escaping (Result<Void, Error>) -> Void) {
            // Reference to the comment document
            let commentRef = db.collection("places")
                              .document(placeId)
                              .collection("reviews")
                              .document(reviewId)
                              .collection("comments")
                              .document(comment.id)
            
            // Add comment to the review's comments subcollection
            do {
                try commentRef.setData(from: comment) { error in
                    if let error = error {
                        print("Error saving comment: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        // Also save to user's comments collection for easier querying
                        let userCommentRef = self.db.collection("users")
                                                .document(comment.userId)
                                                .collection("comments")
                                                .document(comment.id)
                        
                        do {
                            try userCommentRef.setData(from: comment) { error in
                                if let error = error {
                                    print("Error saving user's comment reference: \(error.localizedDescription)")
                                    completion(.failure(error))
                                } else {
                                    completion(.success(()))
                                }
                            }
                        } catch {
                            print("Error encoding comment data for user reference: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                }
            } catch {
                print("Error encoding comment data: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        private func uploadImagesForComment(comment: Comment, images: [UIImage], completion: @escaping (Result<[String], Error>) -> Void) {
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
                
                // 2. Store comment images in a separate folder
                let storageRef = storage.reference()
                    .child("comments/\(comment.id)/\(imageName).jpg")
                
                // 3. Convert the UIImage to JPEG data
                guard let imageData = image.jpegData(compressionQuality: 0.5) else {
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
        
        func fetchComments(placeId: String, reviewId: String, limit: Int = 20, completion: @escaping ([Comment]?, Error?) -> Void) {
            let commentsRef = db.collection("places")
                              .document(placeId)
                              .collection("reviews")
                              .document(reviewId)
                              .collection("comments")
            
            // Get comments, ordered by timestamp with a limit
            commentsRef.order(by: "timestamp", descending: true)
                     .limit(to: limit)
                     .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching comments: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("No snapshot returned for comments")
                    completion([], nil)
                    return
                }
                
                // Decode each document into a Comment object
                let comments: [Comment] = snapshot.documents.compactMap { document in
                    try? document.data(as: Comment.self)
                }
                
                completion(comments, nil)
            }
        }
        
        func likeComment(userId: String, placeId: String, reviewId: String, commentId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            let commentRef = db.collection("places")
                               .document(placeId)
                               .collection("reviews")
                               .document(reviewId)
                               .collection("comments")
                               .document(commentId)
            
            let likeRef = db.collection("commentLikes").document("\(userId)_\(commentId)")
            
            // Use a transaction to handle both the like count and the like record
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                // First check if user has already liked
                let likeDocument: DocumentSnapshot
                do {
                    try likeDocument = transaction.getDocument(likeRef)
                    if likeDocument.exists {
                        let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "User has already liked this comment"
                        ])
                        errorPointer?.pointee = error
                        return nil
                    }
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Then get the comment and increment likes
                let commentDocument: DocumentSnapshot
                do {
                    try commentDocument = transaction.getDocument(commentRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard let oldLikes = commentDocument.data()?["likes"] as? Int else {
                    let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to retrieve likes count"
                    ])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Create the like record
                let likeData: [String: Any] = [
                    "userId": userId,
                    "commentId": commentId,
                    "reviewId": reviewId,
                    "placeId": placeId,
                    "timestamp": FieldValue.serverTimestamp()
                ]
                
                // Update both documents in the transaction
                transaction.setData(likeData, forDocument: likeRef)
                transaction.updateData(["likes": oldLikes + 1], forDocument: commentRef)
                
                return nil
            }) { (_, error) in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
        
        func unlikeComment(userId: String, placeId: String, reviewId: String, commentId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            let commentRef = db.collection("places")
                               .document(placeId)
                               .collection("reviews")
                               .document(reviewId)
                               .collection("comments")
                               .document(commentId)
            
            let likeRef = db.collection("commentLikes").document("\(userId)_\(commentId)")
            
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                // First verify the like exists
                let likeDocument: DocumentSnapshot
                do {
                    try likeDocument = transaction.getDocument(likeRef)
                    if !likeDocument.exists {
                        let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "User has not liked this comment"
                        ])
                        errorPointer?.pointee = error
                        return nil
                    }
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Then get the comment and decrement likes
                let commentDocument: DocumentSnapshot
                do {
                    try commentDocument = transaction.getDocument(commentRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard let oldLikes = commentDocument.data()?["likes"] as? Int else {
                    let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to retrieve likes count"
                    ])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Delete the like record and decrement the count
                transaction.deleteDocument(likeRef)
                transaction.updateData(["likes": max(0, oldLikes - 1)], forDocument: commentRef)
                
                return nil
            }) { (_, error) in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
        
        func hasUserLikedComment(userId: String, commentId: String, completion: @escaping (Bool) -> Void) {
            let likeRef = db.collection("commentLikes").document("\(userId)_\(commentId)")
            
            likeRef.getDocument { document, error in
                if let error = error {
                    print("Error checking comment like status: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                completion(document?.exists ?? false)
            }
        }
        
        func fetchCommentCount(placeId: String, reviewId: String, completion: @escaping (Int?, Error?) -> Void) {
            let commentsRef = db.collection("places")
                              .document(placeId)
                              .collection("reviews")
                              .document(reviewId)
                              .collection("comments")
            
            // Get all documents but limit to just metadata
            commentsRef.getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching comment count: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("No snapshot returned for comment count")
                    completion(0, nil)
                    return
                }
                
                let count = snapshot.documents.count
                completion(count, nil)
            }
        }

    func fetchUserById(userId: String, completion: @escaping (ProfileData?) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Error fetching user \(userId): \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists else {
                print("User \(userId) not found")
                completion(nil)
                return
            }
            
            do {
                let profileData = try document.data(as: ProfileData.self)
                completion(profileData)
            } catch {
                print("Error decoding user \(userId): \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // New implementation that avoids EXC_BAD_ACCESS
    func fetchFriendsReviews(placeId: String, currentUserId: String, completion: @escaping ([ReviewProtocol]?, Error?) -> Void) {
        print("🔍 DEBUG: Starting fetchFriendsReviews for placeId: \(placeId), currentUserId: \(currentUserId)")
        
        // Step 1: Get list of users the current user follows
        fetchFriends(userId: currentUserId) { [weak self] followingIds, error in
            guard let self = self else { 
                print("❌ DEBUG: Self was deallocated in fetchFriends callback")
                completion(nil, NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"]))
                return 
            }
            
            if let error = error {
                print("❌ DEBUG: Error fetching following list: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            // Handle case where user doesn't follow anyone or error occurred
            guard let followingIds = followingIds, !followingIds.isEmpty else {
                print("⚠️ DEBUG: User doesn't follow anyone or followingIds is nil/empty")
                completion([], nil)
                return
            }
            
            print("✅ DEBUG: Successfully fetched \(followingIds.count) following IDs: \(followingIds)")
            
            // Always include the current user's own reviews
            var userIdsToFetch = Set(followingIds)
            userIdsToFetch.insert(currentUserId)
            print("✅ DEBUG: Total users to fetch reviews from: \(userIdsToFetch.count) (including current user)")
            
            // Step 2: Fetch all reviews for the place
            let reviewsRef = self.db.collection("places")
                             .document(placeId)
                             .collection("reviews")
            
            print("🔍 DEBUG: Fetching reviews from path: places/\(placeId)/reviews")
            
            reviewsRef.order(by: "timestamp", descending: true).getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    print("❌ DEBUG: Self was deallocated in getDocuments callback")
                    completion(nil, NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"]))
                    return
                }
                
                if let error = error {
                    print("❌ DEBUG: Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ DEBUG: No snapshot returned for reviews of place \(placeId)")
                    completion([], nil)
                    return
                }
                
                print("✅ DEBUG: Successfully fetched \(snapshot.documents.count) total reviews for place \(placeId)")
                
                // Step 3: Filter reviews to only those from followed users and the current user
                // Use concrete types first to avoid memory issues
                var restaurantReviews: [RestaurantReview] = []
                var genericReviews: [GenericReview] = []
                
                for document in snapshot.documents {
                    // First check if the review is from a user we want to include
                    guard let userId = document.data()["userId"] as? String,
                          userIdsToFetch.contains(userId) else {
                        continue // Skip reviews from users we don't follow
                    }
                    
                    // Check the type field to determine how to decode
                    if let typeString = document.data()["type"] as? String,
                       let type = ReviewType(rawValue: typeString) {
                        
                        switch type {
                        case .restaurant:
                            if let restaurantReview = try? document.data(as: RestaurantReview.self) {
                                print("✅ DEBUG: Found restaurant review from followed user: \(restaurantReview.userId)")
                                restaurantReviews.append(restaurantReview)
                            }
                        case .generic:
                            if let genericReview = try? document.data(as: GenericReview.self) {
                                print("✅ DEBUG: Found generic review from followed user: \(genericReview.userId)")
                                genericReviews.append(genericReview)
                            }
                        }
                    } else {
                        // Fallback to trying both types if type field is missing
                        if let restaurantReview = try? document.data(as: RestaurantReview.self) {
                            print("✅ DEBUG: Found restaurant review (no type field) from followed user: \(restaurantReview.userId)")
                            restaurantReviews.append(restaurantReview)
                        } else if let genericReview = try? document.data(as: GenericReview.self) {
                            print("✅ DEBUG: Found generic review (no type field) from followed user: \(genericReview.userId)")
                            genericReviews.append(genericReview)
                        } else {
                            print("⚠️ DEBUG: Failed to decode review document: \(document.documentID)")
                        }
                    }
                }
                
                print("✅ DEBUG: Found \(restaurantReviews.count) restaurant reviews and \(genericReviews.count) generic reviews")
                
                // Convert to protocol type at the end to avoid memory issues
                var allReviews: [ReviewProtocol] = []
                
                // Add restaurant reviews
                for review in restaurantReviews {
                    allReviews.append(review)
                }
                
                // Add generic reviews
                for review in genericReviews {
                    allReviews.append(review)
                }
                
                print("✅ DEBUG: Total reviews to return: \(allReviews.count)")
                
                // Ensure we're on the main thread when calling the completion handler
                DispatchQueue.main.async {
                    completion(allReviews, nil)
                }
            }
        }
    }
}
