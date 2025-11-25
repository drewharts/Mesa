//
//  SupabaseReviewService.swift
//  loc
//
//  Review service using Supabase (replacement for Firebase ReviewService)
//

import Foundation
import Supabase
import PostgREST

@MainActor
class SupabaseReviewService: ObservableObject {
    static let shared = SupabaseReviewService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Reviews
    
    /// Fetch all reviews for a place
    func fetchReviews<T: ReviewProtocol>(placeId: String, latestOnly: Bool = false) async throws -> [T] {
        var query = supabase.database
            .from("reviews")
            .select()
            .eq("place_id", value: placeId)
            .order("timestamp", ascending: false)
        
        if latestOnly {
            query = query.limit(1)
        }
        
        let response: [Review] = try await query.execute().value
        
        // Convert to concrete types
        return response as! [T]
    }
    
    /// Fetch user's reviews
    func fetchUserReviews<T: ReviewProtocol>(userId: String) async throws -> [T] {
        let response: [Review] = try await supabase.database
            .from("reviews")
            .select()
            .eq("user_id", value: userId)
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        return response as! [T]
    }
    
    /// Fetch reviews from friends for a specific place
    func fetchFriendsReviews(placeId: String, currentUserId: String) async throws -> [ReviewProtocol] {
        // Get following IDs
        let following: [FollowingRecord] = try await supabase.database
            .from("following")
            .select()
            .eq("follower_id", value: currentUserId)
            .execute()
            .value
        
        var userIds = following.map { $0.following_id.uuidString }
        userIds.append(currentUserId) // Include current user's reviews
        
        guard !userIds.isEmpty else { return [] }
        
        // Fetch reviews for this place from these users
        let response: [Review] = try await supabase.database
            .from("reviews")
            .select()
            .eq("place_id", value: placeId)
            .in("user_id", values: userIds)
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        // Convert to ReviewProtocol - this needs user and place data
        // For now, return empty array - will need to fetch user/place data separately
        return []
    }
    
    // MARK: - Save Review
    
    /// Save a review (works for both RestaurantReview and GenericReview)
    func saveReview<T: ReviewProtocol>(_ review: T) async throws {
        print("📝 Saving review with ID: \(review.id)")
        print("📍 Place ID: \(review.placeId)")
        print("👤 User ID: \(review.userId)")
        
        // Convert to Review model for Supabase
        let supabaseReview = Review(from: review)
        
        try await supabase.database
            .from("reviews")
            .upsert(supabaseReview)
            .execute()
        
        print("✅ Successfully saved review")
    }
    
    /// Update an existing review
    func updateReview<T: ReviewProtocol>(_ review: T) async throws {
        let supabaseReview = Review(from: review)
        
        try await supabase.database
            .from("reviews")
            .update(supabaseReview)
            .eq("id", value: review.id)
            .execute()
    }
    
    /// Delete a review
    func deleteReview(reviewId: String) async throws {
        try await supabase.database
            .from("reviews")
            .delete()
            .eq("id", value: reviewId)
            .execute()
    }
    
    // MARK: - Review Likes
    
    /// Like a review
    func likeReview(userId: String, placeId: String, reviewId: String) async throws {
        // Check if already liked
        let existing: [ReviewLikeRecord] = try await supabase.database
            .from("review_likes")
            .select()
            .eq("user_id", value: userId)
            .eq("review_id", value: reviewId)
            .execute()
            .value
        
        guard existing.isEmpty else {
            throw NSError(domain: "ReviewService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "User has already liked this review"
            ])
        }
        
        // Add like
        let like = ReviewLikeRecord(
            id: UUID(),
            review_id: UUID(uuidString: reviewId)!,
            user_id: UUID(uuidString: userId)!,
            timestamp: Date()
        )
        
        try await supabase.database
            .from("review_likes")
            .insert(like)
            .execute()
        
        print("✅ Successfully liked review")
    }
    
    /// Unlike a review
    func unlikeReview(userId: String, placeId: String, reviewId: String) async throws {
        try await supabase.database
            .from("review_likes")
            .delete()
            .eq("user_id", value: userId)
            .eq("review_id", value: reviewId)
            .execute()
        
        print("✅ Successfully unliked review")
    }
    
    /// Check if user has liked a review
    func hasUserLikedReview(userId: String, reviewId: String) async throws -> Bool {
        let response = try await supabase.database
            .from("review_likes")
            .select(count: .exact)
            .eq("user_id", value: userId)
            .eq("review_id", value: reviewId)
            .execute()
        
        return (response.count ?? 0) > 0
    }
    
    /// Get like count for a review
    func getLikeCount(reviewId: String) async throws -> Int {
        let response = try await supabase.database
            .from("review_likes")
            .select(count: .exact)
            .eq("review_id", value: reviewId)
            .execute()
        
        return response.count ?? 0
    }
    
    /// Get users who liked a review
    func getUsersWhoLiked(reviewId: String) async throws -> [String] {
        let response: [ReviewLikeRecord] = try await supabase.database
            .from("review_likes")
            .select()
            .eq("review_id", value: reviewId)
            .execute()
            .value
        
        return response.map { $0.user_id.uuidString }
    }
    
    // MARK: - Comments
    
    /// Fetch comments for a review
    func fetchComments(reviewId: String) async throws -> [Comment] {
        let response: [Comment] = try await supabase.database
            .from("comments")
            .select()
            .eq("review_id", value: reviewId)
            .order("timestamp", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    /// Add a comment to a review
    func addComment(comment: Comment) async throws {
        try await supabase.database
            .from("comments")
            .insert(comment)
            .execute()
        
        print("✅ Successfully added comment")
    }
    
    /// Update a comment
    func updateComment(comment: Comment) async throws {
        try await supabase.database
            .from("comments")
            .update(comment)
            .eq("id", value: comment.id)
            .execute()
    }
    
    /// Delete a comment
    func deleteComment(commentId: String) async throws {
        try await supabase.database
            .from("comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
        
        print("✅ Successfully deleted comment")
    }
    
    // MARK: - Photo Upload
    
    /// Upload review photos to Supabase Storage
    func uploadReviewPhotos(reviewId: String, images: [Data]) async throws -> [String] {
        // TODO: Implement storage upload when StorageClient is fixed
        print("⚠️ [SupabaseReviewService] uploadReviewPhotos not yet implemented - StorageClient issue")
        return []
    }
    
    /// Upload comment photos to Supabase Storage
    func uploadCommentPhotos(commentId: String, images: [Data]) async throws -> [String] {
        // TODO: Implement storage upload when StorageClient is fixed
        print("⚠️ [SupabaseReviewService] uploadCommentPhotos not yet implemented - StorageClient issue")
        return []
    }
    
    // MARK: - Statistics
    
    /// Get review count for a place
    func getReviewCount(placeId: String) async throws -> Int {
        let response = try await supabase.database
            .from("reviews")
            .select(count: .exact)
            .eq("place_id", value: placeId)
            .execute()
        
        return response.count ?? 0
    }
    
    /// Get average rating for a place
    func getAverageRating(placeId: String) async throws -> Double? {
        // Use RPC function for aggregation
        let response: AverageRatingResult = try await supabase.database
            .rpc("get_average_rating", params: ["p_place_id": placeId])
            .execute()
            .value
        
        return response.average_rating
    }
    
    // MARK: - Compatibility Methods (callback-based)
    
    func fetchReviews<T>(placeId: String, latestOnly: Bool = false, completion: @escaping ([T]?, Error?) -> Void) {
        Task {
            do {
                let reviews: [T] = try await fetchReviews(placeId: placeId, latestOnly: latestOnly)
                completion(reviews, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func saveReview<T: ReviewProtocol>(_ review: T, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await saveReview(review)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func likeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await likeReview(userId: userId, placeId: placeId, reviewId: reviewId)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func unlikeReview(userId: String, placeId: String, reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await unlikeReview(userId: userId, placeId: placeId, reviewId: reviewId)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func fetchComments(reviewId: String, completion: @escaping ([Comment]?, Error?) -> Void) {
        Task {
            do {
                let comments = try await fetchComments(reviewId: reviewId)
                completion(comments, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func addComment(comment: Comment, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await addComment(comment: comment)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Helper Models

struct Review: Codable {
    let id: UUID
    let user_id: UUID
    let place_id: UUID
    let type: String
    let rating: Int?
    let text: String?
    let photo_urls: [String]?
    let timestamp: Date
    
    // Restaurant-specific fields
    let food_rating: Int?
    let service_rating: Int?
    let ambiance_rating: Int?
    let value_rating: Int?
    let would_recommend: Bool?
    
    let created_at: Date
    let updated_at: Date
    
    // Convert to ReviewProtocol (requires user and place data)
    func toReviewProtocol(userFirstName: String, userLastName: String, profilePhotoUrl: String, placeName: String) -> ReviewProtocol {
        if type == "restaurant" {
            return RestaurantReview(
                id: id.uuidString,
                userId: user_id.uuidString,
                profilePhotoUrl: profilePhotoUrl,
                userFirstName: userFirstName,
                userLastName: userLastName,
                placeId: place_id.uuidString,
                placeName: placeName,
                foodRating: Double(food_rating ?? 0),
                serviceRating: Double(service_rating ?? 0),
                ambienceRating: Double(ambiance_rating ?? 0),
                favoriteDishes: [], // TODO: Add to schema if needed
                reviewText: text ?? "",
                timestamp: timestamp,
                images: photo_urls ?? [],
                likes: 0 // TODO: Get from review_likes table
            )
        } else {
            return GenericReview(
                id: id.uuidString,
                userId: user_id.uuidString,
                profilePhotoUrl: profilePhotoUrl,
                userFirstName: userFirstName,
                userLastName: userLastName,
                placeId: place_id.uuidString,
                placeName: placeName,
                reviewText: text ?? "",
                timestamp: timestamp,
                images: photo_urls ?? [],
                likes: 0 // TODO: Get from review_likes table
            )
        }
    }
    
    // Convert from ReviewProtocol
    init(from review: ReviewProtocol) {
        self.id = UUID(uuidString: review.id)!
        self.user_id = UUID(uuidString: review.userId)!
        self.place_id = UUID(uuidString: review.placeId)!
        self.type = review.type.rawValue
        self.timestamp = review.timestamp
        self.photo_urls = review.images
        self.created_at = Date()
        self.updated_at = Date()
        
        // Type-specific fields
        if let restaurantReview = review as? RestaurantReview {
            self.rating = nil
            self.text = restaurantReview.reviewText
            self.food_rating = Int(restaurantReview.foodRating)
            self.service_rating = Int(restaurantReview.serviceRating)
            self.ambiance_rating = Int(restaurantReview.ambienceRating)
            self.value_rating = nil // Not in RestaurantReview
            self.would_recommend = nil // Not in RestaurantReview
        } else if let genericReview = review as? GenericReview {
            self.rating = nil // Not in GenericReview
            self.text = genericReview.reviewText
            self.food_rating = nil
            self.service_rating = nil
            self.ambiance_rating = nil
            self.value_rating = nil
            self.would_recommend = nil
        } else {
            self.rating = nil
            self.text = review.reviewText
            self.food_rating = nil
            self.service_rating = nil
            self.ambiance_rating = nil
            self.value_rating = nil
            self.would_recommend = nil
        }
    }
}

struct ReviewLikeRecord: Codable {
    let id: UUID
    let review_id: UUID
    let user_id: UUID
    let timestamp: Date
}

struct FollowingRecord: Codable {
    let id: UUID
    let follower_id: UUID
    let following_id: UUID
}

struct AverageRatingResult: Codable {
    let average_rating: Double?
}

