//
//  SupabaseReviewService.swift
//  loc
//
//  Review service using Supabase (replacement for Firebase ReviewService)
//

import Foundation
import Supabase

@MainActor
class SupabaseReviewService: ObservableObject {
    static let shared = SupabaseReviewService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Reviews (matching Firebase ReviewService interface)
    
    func fetchReviews<T>(placeId: String, latestOnly: Bool = false, completion: @escaping ([T]?, Error?) -> Void) {
        Task {
            do {
                var query = supabase.client
                    .from("reviews")
                    .select()
                    .eq("place_id", value: placeId)
                    .order("timestamp", ascending: false)
                
                if latestOnly {
                    query = query.limit(1)
                }
                
                let response: [ReviewRecord] = try await query.execute().value
                
                // For now, return empty array as we need to handle ReviewProtocol conversion
                // The app will need to be updated to work with the new data structure
                completion([] as? [T], nil)
            } catch {
                print("❌ [Supabase] Error fetching reviews: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func saveReview(placeId: String, review: ReviewProtocol, images: [Data], completion: @escaping (Error?) -> Void) {
        Task {
            do {
                // Create a proper ReviewRecord for database insertion
                let reviewRecord = ReviewRecord(
                    id: review.id,
                    place_id: review.placeId,
                    user_id: review.userId,
                    user_first_name: review.userFirstName,
                    user_last_name: review.userLastName,
                    profile_photo_url: review.profilePhotoUrl,
                    place_name: review.placeName,
                    food_rating: (review as? RestaurantReview)?.foodRating,
                    service_rating: (review as? RestaurantReview)?.serviceRating,
                    ambience_rating: (review as? RestaurantReview)?.ambienceRating,
                    favorite_dishes: (review as? RestaurantReview)?.favoriteDishes,
                    review_text: review.reviewText,
                    images: review.images,
                    timestamp: review.timestamp,  // Now passing Date directly instead of string
                    likes: review.likes,
                    type: review.type.rawValue
                )
                
                // Insert the review into the database
                try await supabase.client
                    .from("reviews")
                    .insert(reviewRecord)
                    .execute()
                
                completion(nil)
                
            } catch {
                print("❌ [Supabase] Error saving review: \(error)")
                print("❌ [Supabase] Error details: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    // MARK: - Review Likes
    
    func likeReview(reviewId: String, userId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("review_likes")
                    .insert([
                        "review_id": reviewId,
                        "user_id": userId
                    ])
                    .execute()
                
                completion(nil)
            } catch {
                print("❌ [Supabase] Error liking review: \(error)")
                completion(error)
            }
        }
    }
    
    func unlikeReview(reviewId: String, userId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("review_likes")
                    .delete()
                    .eq("review_id", value: reviewId)
                    .eq("user_id", value: userId)
                    .execute()
                
                completion(nil)
            } catch {
                print("❌ [Supabase] Error unliking review: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - User Reviews
    
    func fetchUserReviews(userId: String) async throws -> [RestaurantReview] {
        let response: [ReviewRecord] = try await supabase.client
            .from("reviews")
            .select()
            .eq("user_id", value: userId)
            .eq("type", value: "restaurant")
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        let reviews = response.compactMap { record -> RestaurantReview? in
            // Use timestamp directly since it's now a Date object
            let timestamp = record.timestamp
            
            return RestaurantReview(
                id: record.id,
                userId: record.user_id,
                profilePhotoUrl: record.profile_photo_url ?? "",
                userFirstName: record.user_first_name ?? "",
                userLastName: record.user_last_name ?? "",
                placeId: record.place_id,
                placeName: record.place_name ?? "",
                foodRating: record.food_rating ?? 0,
                serviceRating: record.service_rating ?? 0,
                ambienceRating: record.ambience_rating ?? 0,
                favoriteDishes: record.favorite_dishes ?? [],
                reviewText: record.review_text ?? "",
                timestamp: timestamp,
                images: record.images ?? [],
                likes: record.likes ?? 0
            )
        }
        
        return reviews
    }
    
    func fetchUserGenericReviews(userId: String) async throws -> [GenericReview] {
        let response: [ReviewRecord] = try await supabase.client
            .from("reviews")
            .select()
            .eq("user_id", value: userId)
            .eq("type", value: "generic")
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        let reviews = response.compactMap { record -> GenericReview? in
            // Use timestamp directly since it's now a Date object
            let timestamp = record.timestamp
            
            return GenericReview(
                id: record.id,
                userId: record.user_id,
                profilePhotoUrl: record.profile_photo_url ?? "",
                userFirstName: record.user_first_name ?? "",
                userLastName: record.user_last_name ?? "",
                placeId: record.place_id,
                placeName: record.place_name ?? "",
                reviewText: record.review_text ?? "",
                timestamp: timestamp,
                images: record.images ?? [],
                likes: record.likes ?? 0
            )
        }
        
        return reviews
    }
    
    // MARK: - Place Reviews
    
    func fetchPlaceReviews(placeId: String, latestOnly: Bool = false) async throws -> ([ReviewProtocol], [TikTokVideo]) {
        // Call the new SQL function that returns reviews + TikToks in a single query
        let response: [ReviewWithTikToksRecord] = try await supabase.client
            .rpc("get_place_reviews_with_tiktoks", params: ["p_place_id": placeId])
            .execute()
            .value
        
        // Extract TikToks from the first row (they're the same for all rows)
        var tiktokVideos: [TikTokVideo] = []
        
        // If no reviews, fetch TikToks separately (place might have TikToks but no reviews)
        if response.isEmpty {
            struct TikTokArrayRecord: Codable {
                let tiktok_videos: [AnyCodable]?
            }
            
            let tiktokResponse: [TikTokArrayRecord] = try await supabase.client
                .rpc("get_place_tiktoks", params: ["p_place_id": placeId])
                .execute()
                .value
            
            if let firstRecord = tiktokResponse.first,
               let tiktokArray = firstRecord.tiktok_videos {
                // Convert [AnyCodable] to [[String: Any]]
                let tiktokData = tiktokArray.compactMap { $0.value as? [String: Any] }
                tiktokVideos = parseTikTokData(tiktokData)
            }
            
            return ([], tiktokVideos) // No reviews, but may have TikToks
        }
        
        // Extract TikToks from reviews response
        if let firstRecord = response.first,
           let tiktokArray = firstRecord.tiktok_videos {
            // Convert [AnyCodable] to [[String: Any]]
            let tiktokData = tiktokArray.compactMap { $0.value as? [String: Any] }
            tiktokVideos = parseTikTokData(tiktokData)
        }
        
        // Convert records to ReviewProtocol objects
        let reviews: [ReviewProtocol] = response.compactMap { record -> ReviewProtocol? in
            // Parse PostgreSQL TIMESTAMP format to Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            let timestamp = dateFormatter.date(from: record.review_timestamp) ?? Date()
            
            // Create GenericReview with user information from the SQL function
            return GenericReview(
                id: record.review_id,
                userId: record.review_user_id,
                profilePhotoUrl: record.user_profile_photo_url ?? "",
                userFirstName: record.user_first_name ?? "",
                userLastName: record.user_last_name ?? "",
                placeId: placeId,
                placeName: "",
                reviewText: record.review_text,
                timestamp: timestamp,
                images: record.review_images ?? [],
                likes: record.review_likes ?? 0
            )
        }
        
        // Apply latestOnly filter if needed
        if latestOnly && !reviews.isEmpty {
            return ([reviews[0]], tiktokVideos)
        }
        
        return (reviews, tiktokVideos)
    }
    
    // MARK: - Comments
    
    func fetchComments(reviewId: String, completion: @escaping ([Comment]?, Error?) -> Void) {
        Task {
            do {
                let response: [CommentRecord] = try await supabase.client
                    .from("comments")
                    .select()
                    .eq("review_id", value: reviewId)
                    .order("timestamp", ascending: true)
                    .execute()
                    .value
                
                let comments = response.compactMap { record -> Comment? in
                    // Parse timestamp from string
                    let formatter = ISO8601DateFormatter()
                    guard let timestamp = formatter.date(from: record.timestamp) else {
                        print("⚠️ [Supabase] Failed to parse timestamp for comment \(record.id)")
                        return nil
                    }
                    
                    return Comment(
                        id: record.id,
                        reviewId: record.review_id,
                        userId: record.user_id,
                        profilePhotoUrl: "", // Will be populated from user data
                        userFirstName: "", // Will be populated from user data
                        userLastName: "", // Will be populated from user data
                        commentText: record.text,
                        timestamp: timestamp,
                        images: record.photo_urls ?? [],
                        likes: 0 // Comments don't have likes in current schema
                    )
                }
                
                completion(comments, nil)
            } catch {
                print("❌ [Supabase] Error fetching comments: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func addComment(reviewId: String, userId: String, text: String, photoUrls: [String] = [], completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let commentRecord = CommentRecord(
                    id: UUID().uuidString,
                    review_id: reviewId,
                    user_id: userId,
                    text: text,
                    photo_urls: photoUrls,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                try await supabase.client
                    .from("comments")
                    .insert(commentRecord)
                    .execute()
                
                completion(nil)
            } catch {
                print("❌ [Supabase] Error adding comment: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseTikTokData(_ tiktokData: [[String: Any]]) -> [TikTokVideo] {
        return tiktokData.compactMap { dict -> TikTokVideo? in
            // Only require video_id and url - other fields can be empty
            guard let videoId = dict["video_id"] as? String,
                  let videoUrl = dict["url"] as? String else {
                return nil
            }
            
            // Parse author (may be empty)
            var author = TikTokAuthor(displayName: "", url: "", username: "")
            if let authorDict = dict["author"] as? [String: Any] {
                author = TikTokAuthor(
                    displayName: authorDict["display_name"] as? String ?? "",
                    url: authorDict["url"] as? String ?? "",
                    username: authorDict["username"] as? String ?? ""
                )
            }
            
            return TikTokVideo(
                videoID: videoId,
                url: videoUrl,
                title: dict["title"] as? String,
                caption: dict["caption"] as? String,
                embedHTML: dict["embed_html"] as? String ?? "", // Can be empty
                thumbnailURL: dict["thumbnail_url"] as? String ?? "", // Can be empty
                author: author,
                hashtags: dict["hashtags"] as? [String] ?? [],
                createdAt: dict["created_at"] as? String ?? ""
            )
        }
    }
}

// MARK: - Supabase Data Models

struct ReviewRecord: Codable {
    let id: String
    let place_id: String
    let user_id: String
    let user_first_name: String?
    let user_last_name: String?
    let profile_photo_url: String?
    let place_name: String?
    let food_rating: Double?
    let service_rating: Double?
    let ambience_rating: Double?
    let favorite_dishes: [String]?
    let review_text: String?
    let images: [String]?
    let timestamp: Date  // Changed from String to Date to match database schema
    let likes: Int?      // Database defaults to 0, but we'll send explicit value
    let type: String?    // Database defaults to 'restaurant', but we'll send explicit value
}

struct ReviewWithTikToksRecord: Codable {
    let review_id: String
    let review_user_id: String
    let review_text: String
    let review_images: [String]?
    let review_timestamp: String
    let review_type: String?
    let review_likes: Int?
    let user_first_name: String?
    let user_last_name: String?
    let user_profile_photo_url: String?
    let tiktok_videos: [AnyCodable]? // JSONB[] array of TikTok videos
}

struct CommentRecord: Codable {
    let id: String
    let review_id: String
    let user_id: String
    let text: String
    let photo_urls: [String]?
    let timestamp: String
    let created_at: String?
}
