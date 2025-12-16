//
//  SupabaseReviewService.swift
//  loc
//
//  Legacy service - kept for backward compatibility
//  New code should use SupabasePostService directly
//

import Foundation
import Supabase

@MainActor
class SupabaseReviewService: ObservableObject {
    static let shared = SupabaseReviewService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
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
    
    // MARK: - Reviewed Place Checks
    
    /// Check which places from a given list the user has reviewed
    /// Returns an array of place IDs that the user HAS reviewed
    /// Used for "show only unvisited" filtering
    func getReviewedPlaceIds(userId: String, placeIds: [String]) async throws -> Set<String> {
        guard !placeIds.isEmpty else { return [] }
        
        struct Params: Encodable {
            let p_user_id: String
            let p_place_ids: [String]
        }
        
        let params = Params(p_user_id: userId, p_place_ids: placeIds)
        
        let reviewedIds: [String] = try await supabase.client
            .rpc("get_user_reviewed_place_ids", params: params)
            .execute()
            .value
        
        return Set(reviewedIds)
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
                    let formatter = ISO8601DateFormatter()
                    guard let timestamp = formatter.date(from: record.timestamp) else {
                        print("⚠️ [Supabase] Failed to parse timestamp for comment \(record.id)")
                        return nil
                    }
                    
                    return Comment(
                        id: record.id,
                        reviewId: record.review_id,
                        userId: record.user_id,
                        profilePhotoUrl: "",
                        userFirstName: "",
                        userLastName: "",
                        commentText: record.text,
                        timestamp: timestamp,
                        images: record.photo_urls ?? [],
                        likes: 0
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
    
    // MARK: - External Review Media
    
    func fetchExternalReviewMedia(placeId: String, reviewOffset: Int, reviewLimit: Int) async throws -> (urls: [String], nextReviewOffset: Int, hasMore: Bool) {
        struct ExternalReviewMediaRecord: Codable {
            let type: String?
            let imageUrl: String?
        }
        
        struct ExternalReviewRecord: Codable {
            let id: String
            let media: [ExternalReviewMediaRecord]?
        }
        
        let records: [ExternalReviewRecord] = try await supabase.client
            .from("external_reviews")
            .select("id, media")
            .eq("place_id", value: placeId)
            .order("review_iso_date", ascending: false)
            .range(from: reviewOffset, to: reviewOffset + reviewLimit - 1)
            .execute()
            .value
        
        var imageUrls: [String] = []
        
        for record in records {
            guard let mediaItems = record.media else { continue }
            let urls = mediaItems.compactMap { item -> String? in
                guard let type = item.type, type.lowercased() == "image" else { return nil }
                guard let url = item.imageUrl, !url.isEmpty else { return nil }
                return url
            }
            imageUrls.append(contentsOf: urls)
        }
        
        let nextOffset = reviewOffset + records.count
        let hasMore = records.count == reviewLimit
        
        return (imageUrls, nextOffset, hasMore)
    }
}

// MARK: - Data Models

struct CommentRecord: Codable {
    let id: String
    let review_id: String
    let user_id: String
    let text: String
    let photo_urls: [String]?
    let timestamp: String
    let created_at: String?
}
