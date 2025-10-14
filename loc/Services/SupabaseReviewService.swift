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
                print("📝 [Supabase] Fetching reviews for place \(placeId)")
                
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
                print("✅ [Supabase] Fetched \(response.count) reviews")
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
                // TODO: Upload images to Supabase Storage
                // For now, return success without actually saving
                print("✅ [Supabase] Review save placeholder - not yet fully implemented")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error saving review: \(error)")
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
                
                print("✅ [Supabase] Review liked")
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
                
                print("✅ [Supabase] Review unliked")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error unliking review: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Comments
    
    func fetchComments(reviewId: String, completion: @escaping ([Comment]?, Error?) -> Void) {
        Task {
            do {
                // TODO: Implement comment fetching when Comment model is properly mapped
                print("✅ [Supabase] Comment fetch placeholder - not yet fully implemented")
                completion([], nil)
            } catch {
                print("❌ [Supabase] Error fetching comments: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func addComment(reviewId: String, userId: String, text: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("comments")
                    .insert([
                        "review_id": reviewId,
                        "user_id": userId,
                        "text": text,
                        "timestamp": ISO8601DateFormatter().string(from: Date())
                    ])
                    .execute()
                
                print("✅ [Supabase] Comment added")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error adding comment: \(error)")
                completion(error)
            }
        }
    }
}

// MARK: - Supabase Data Models

struct ReviewRecord: Codable {
    let id: String
    let place_id: String
    let user_id: String
    let type: String
    let rating: Int?
    let text: String?
    let photo_urls: [String]?
    let timestamp: String
    let food_rating: Int?
    let service_rating: Int?
    let ambiance_rating: Int?
    let value_rating: Int?
    let would_recommend: Bool?
}

struct CommentRecord: Codable {
    let id: String
    let review_id: String
    let user_id: String
    let text: String
    let photo_urls: [String]?
    let timestamp: String
}
