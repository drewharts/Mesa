import Foundation
import Firebase

class ReviewService: ObservableObject {
    static let shared = ReviewService()
    private let db = FirebaseManager.shared.db
    private let storage = FirebaseManager.shared.storage
    
    private init() {}

    func fetchReviews<T>(placeId: String, latestOnly: Bool = false, completion: @escaping ([T]?, Error?) -> Void) {
        // Reference to the reviews subcollection under the place document
        let reviewsRef = db.collection("places")
                         .document(placeId)
                         .collection("reviews")
        
        // Create the query based on the latestOnly flag
        let query = latestOnly ?
            reviewsRef.order(by: "timestamp", descending: true).limit(to: 1) : // Latest review only
            reviewsRef.order(by: "timestamp", descending: true)              // All reviews, most recent first
        
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
            
            // Use concrete types first to avoid memory issues
            var restaurantReviews: [RestaurantReview] = []
            var genericReviews: [GenericReview] = []
            
            for document in snapshot.documents {
                let data = document.data()
                let ts = data["timestamp"]
                var dateString = "(unparsed)"
                if let ts = ts as? Timestamp {
                    dateString = "\(ts.dateValue())"
                } else if let date = ts as? Date {
                    dateString = "\(date)"
                } else {
                    dateString = String(describing: ts)
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
            let typedReviews = allReviewsSorted as! [T]
            // Ensure we're on the main thread when calling the completion handler
            DispatchQueue.main.async {
                completion(typedReviews, nil)
            }
        }
    }

        func saveReviewWithImages<T: ReviewProtocol>(
        review: T,
        images: [UIImage],
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        print("🖼️ Starting saveReviewWithImages process")
        print("📝 Review ID: \(review.id)")
        print("📸 Number of images to upload: \(images.count)")
        
        // If there are no images, just save the review
        if images.isEmpty {
            print("ℹ️ No images to upload, proceeding with review save only")
            saveReview(review) { result in
                switch result {
                case .success:
                    print("✅ Successfully saved review without images")
                    completion(.success(review))
                case .failure(let error):
                    print("❌ Error saving review without images: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
            return
        }
        
        // Upload images first
        print("🔄 Starting image upload process")
        uploadImagesForReview(review: review, images: images) { [weak self] result in
            guard let self = self else {
                print("❌ Self was deallocated during image upload")
                return
            }
            
            switch result {
            case .success(let imageUrls):
                print("✅ Successfully uploaded \(imageUrls.count) images")
                print("🔗 Image URLs: \(imageUrls)")
                
                // Create a new review with the image URLs
                var updatedReview = review
                updatedReview.images = imageUrls
                
                print("🔄 Saving review with image URLs")
                // Save the review with the image URLs
                self.saveReview(updatedReview) { result in
                    switch result {
                    case .success:
                        print("✅ Successfully saved review with images")
                        completion(.success(updatedReview))
                    case .failure(let error):
                        print("❌ Error saving review with images: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("❌ Error uploading images: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

        func saveReview<T: ReviewProtocol>(_ review: T, completion: @escaping (Result<Void, Error>) -> Void) {
        print("📝 Starting to save review with ID: \(review.id)")
        print("📍 Place ID: \(review.placeId)")
        print("👤 User ID: \(review.userId)")
        
        // 1. Build references for both locations
        let placeReviewRef = db.collection("places")
                              .document(review.placeId)
                              .collection("reviews")
                              .document(review.id)
        
        let userReviewRef = db.collection("users")
                             .document(review.userId)
                             .collection("reviews")
                             .document(review.id)
        
        print("🔍 Created Firestore references:")
        print("   - Place review path: \(placeReviewRef.path)")
        print("   - User review path: \(userReviewRef.path)")
        
        // 2. Encode the Review
        do {
            let reviewData = try Firestore.Encoder().encode(review)
            print("✅ Successfully encoded review data")
            
            // 3. Use a batch write to save to both locations atomically
            let batch = db.batch()
            batch.setData(reviewData, forDocument: placeReviewRef)
            batch.setData(reviewData, forDocument: userReviewRef)
            
            print("🔄 Committing batch write...")
            batch.commit { error in
                if let error = error {
                    print("❌ Error saving review: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully saved review to both locations")
                    completion(.success(()))
                }
            }
        } catch {
            print("❌ Error encoding review: \(error.localizedDescription)")
            completion(.failure(error))
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

        private func deleteReviewLikes(reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("👍 Deleting likes for review \(reviewId)")
        
        // Find all likes for this review
        db.collection("reviewLikes")
            .whereField("reviewId", isEqualTo: reviewId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"])))
                    return
                }
                
                if let error = error {
                    print("⚠️ Error fetching review likes: \(error.localizedDescription)")
                    // Don't fail the entire operation for this
                    completion(.success(()))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ No likes found for review")
                    completion(.success(()))
                    return
                }
                
                print("🗑️ Deleting \(documents.count) likes for review")
                
                // Delete all like documents in a batch
                let batch = self.db.batch()
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("⚠️ Error deleting review likes: \(error.localizedDescription)")
                        // Don't fail the entire operation for this
                    } else {
                        print("✅ Successfully deleted review likes")
                    }
                    completion(.success(()))
                }
            }
    }

    private func deleteReviewDocuments(reviewId: String, placeId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("📝 Deleting review documents from both collections")
        
        // References to both review locations
        let placeReviewRef = db.collection("places")
                              .document(placeId)
                              .collection("reviews")
                              .document(reviewId)
        
        let userReviewRef = db.collection("users")
                             .document(userId)
                             .collection("reviews")
                             .document(reviewId)
        
        // Use a batch write to delete from both locations atomically
        let batch = db.batch()
        batch.deleteDocument(placeReviewRef)
        batch.deleteDocument(userReviewRef)
        
        // Also delete any associated likes
        deleteReviewLikes(reviewId: reviewId) { [weak self] _ in
            guard let self = self else { return }
            
            // Commit the batch deletion
            batch.commit { error in
                if let error = error {
                    print("❌ Error deleting review documents: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully deleted review documents from both collections")
                    completion(.success(()))
                }
            }
        }
    }

        private func deleteReviewImages(reviewId: String, imageUrls: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        // If no images to delete, return success immediately
        guard !imageUrls.isEmpty else {
            completion(.success(()))
            return
        }
        
        print("🖼️ Deleting \(imageUrls.count) images for review \(reviewId)")
        
        // Also delete the entire review folder from Storage
        let reviewFolderRef = storage.reference().child("reviews/\(reviewId)")
        
        // List all items in the review folder and delete them
        reviewFolderRef.listAll { result, error in
            if let error = error {
                print("⚠️ Error listing review images: \(error.localizedDescription)")
                // Don't fail the entire operation for this
                completion(.success(()))
                return
            }
            
            guard let result = result else {
                completion(.success(()))
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var deletionErrors: [Error] = []
            
            // Delete each file in the folder
            for item in result.items {
                dispatchGroup.enter()
                item.delete { error in
                    if let error = error {
                        print("⚠️ Error deleting image \(item.name): \(error.localizedDescription)")
                        deletionErrors.append(error)
                    } else {
                        print("✅ Deleted image: \(item.name)")
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if deletionErrors.isEmpty {
                    completion(.success(()))
                } else {
                    // Return the first error but don't fail the entire operation
                    print("⚠️ Some images failed to delete, but continuing with review deletion")
                    completion(.success(()))
                }
            }
        }
    }

        func deleteReview(reviewId: String, placeId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🗑️ Starting review deletion process for ID: \(reviewId)")
        print("📍 Place ID: \(placeId), User ID: \(userId)")
        
        // First fetch the review to get image URLs
        let reviewRef = db.collection("places")
                         .document(placeId)
                         .collection("reviews")
                         .document(reviewId)
        
        reviewRef.getDocument { [weak self] document, error in
            guard let self = self else {
                completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"])))
                return
            }
            
            if let error = error {
                print("❌ Error fetching review: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ Review not found")
                completion(.failure(NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Review not found"])))
                return
            }
            
            // Get image URLs from the review
            let imageUrls = document.data()?["images"] as? [String] ?? []
            print("📸 Found \(imageUrls.count) images to delete")
            
            // Delete images from Storage first
            self.deleteReviewImages(reviewId: reviewId, imageUrls: imageUrls) { [weak self] imageDeleteResult in
                guard let self = self else { return }
                
                switch imageDeleteResult {
                case .success:
                    print("✅ Successfully deleted review images")
                case .failure(let error):
                    print("⚠️ Warning: Failed to delete some images: \(error.localizedDescription)")
                    // Continue with review deletion even if image deletion fails
                }
                
                // Delete the review documents from both collections
                self.deleteReviewDocuments(reviewId: reviewId, placeId: placeId, userId: userId) { result in
                    switch result {
                    case .success:
                        print("✅ Successfully deleted review documents")
                        completion(.success(()))
                    case .failure(let error):
                        print("❌ Error deleting review documents: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            }
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

    func fetchUserReviews<T: ReviewProtocol>(userId: String) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchUserReviews(userId: userId) { (reviews: [T]?, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: reviews ?? [])
                }
            }
        }
    }

    // MARK: - Reviews
    // Functions like fetchReviews, saveReview, likeReview, unlikeReview, hasUserLikedReview, deleteReview, fetchFriendsReviews, fetchUserReviews will go here.
    
    // MARK: - Comments
    // Functions like addComment, fetchComments, likeComment, unlikeComment, hasUserLikedComment, fetchCommentCount will go here.
} 
