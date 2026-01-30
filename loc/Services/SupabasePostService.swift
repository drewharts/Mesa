//
//  SupabasePostService.swift
//  loc
//
//  Post service using Supabase
//

import Foundation
import Supabase

@MainActor
class SupabasePostService: ObservableObject {
    static let shared = SupabasePostService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Save Post
    
    func savePost(post: PlacePost, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let postRecord = PostRecord(
                    id: post.id,
                    place_id: post.placeId,
                    user_id: post.userId,
                    user_first_name: post.userFirstName,
                    user_last_name: post.userLastName,
                    profile_photo_url: post.profilePhotoUrl,
                    place_name: post.placeName,
                    review_text: post.text,
                    images: post.images,
                    timestamp: post.timestamp,
                    likes: post.likes,
                    type: "generic",
                    would_return: post.wouldReturn
                )
                
                try await supabase.client
                    .from("reviews")
                    .insert(postRecord)
                    .execute()
                
                completion(nil)
                
            } catch {
                print("Error saving post: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Delete Post
    
    func deletePost(postId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("reviews")
                    .delete()
                    .eq("id", value: postId)
                    .execute()
                
                completion(nil)
            } catch {
                print("Error deleting post: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Fetch Place Posts
    
    func fetchPlacePosts(placeId: String, latestOnly: Bool = false) async throws -> ([PlacePost], [TikTokVideo]) {
        // Convert placeId to UUID to avoid function ambiguity in Postgres
        guard let placeUUID = UUID(uuidString: placeId) else {
            print("❌ [SupabasePostService] Invalid place ID format: \(placeId)")
            return ([], [])
        }
        
        // Call the SQL function that returns posts with user info
        let response: [PostWithUserRecord] = try await supabase.client
            .rpc("get_place_reviews_with_tiktoks", params: ["p_place_id": placeUUID])
            .execute()
            .value
        
        // Fetch TikToks separately
        struct TikTokArrayRecord: Codable {
            let tiktok_videos: [AnyCodable]?
        }
        
        let tiktokResponse: [TikTokArrayRecord] = try await supabase.client
            .rpc("get_place_tiktoks", params: ["p_place_id": placeUUID])
            .execute()
            .value
        
        var tiktokVideos: [TikTokVideo] = []

        if let firstRecord = tiktokResponse.first,
           let tiktokArray = firstRecord.tiktok_videos {
            let tiktokData = tiktokArray.compactMap { $0.value as? [String: Any] }
            tiktokVideos = parseTikTokData(tiktokData)
        }

        print("🎬 [SupabasePostService] get_place_tiktoks returned \(tiktokVideos.count) videos for place \(placeId)")

        if response.isEmpty {
            return ([], tiktokVideos)
        }
        
        // Convert records to PlacePost objects
        let posts: [PlacePost] = response.compactMap { record -> PlacePost? in
            let timestamp = parseTimestamp(record.review_timestamp)
            
            return PlacePost(
                id: record.review_id,
                userId: record.review_user_id,
                profilePhotoUrl: record.user_profile_photo_url ?? "",
                userFirstName: record.user_first_name ?? "",
                userLastName: record.user_last_name ?? "",
                placeId: placeId,
                placeName: "",
                text: record.review_text,
                timestamp: timestamp,
                images: record.review_images ?? [],
                likes: record.review_likes ?? 0,
                wouldReturn: record.would_return
            )
        }
        
        if latestOnly && !posts.isEmpty {
            return ([posts[0]], tiktokVideos)
        }
        
        return (posts, tiktokVideos)
    }
    
    // MARK: - Fetch User Posts
    
    func fetchUserPosts(userId: String) async throws -> [PlacePost] {
        let response: [PostRecord] = try await supabase.client
            .from("reviews")
            .select()
            .eq("user_id", value: userId)
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        return response.map { record in
            PlacePost(
                id: record.id,
                userId: record.user_id,
                profilePhotoUrl: record.profile_photo_url ?? "",
                userFirstName: record.user_first_name ?? "",
                userLastName: record.user_last_name ?? "",
                placeId: record.place_id,
                placeName: record.place_name ?? "",
                text: record.review_text ?? "",
                timestamp: record.timestamp,
                images: record.images ?? [],
                likes: record.likes ?? 0,
                wouldReturn: record.would_return
            )
        }
    }
    
    // MARK: - Likes
    
    func likePost(postId: String, userId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("review_likes")
                    .insert([
                        "review_id": postId,
                        "user_id": userId
                    ])
                    .execute()
                
                completion(nil)
            } catch {
                print("Error liking post: \(error)")
                completion(error)
            }
        }
    }
    
    func unlikePost(postId: String, userId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("review_likes")
                    .delete()
                    .eq("review_id", value: postId)
                    .eq("user_id", value: userId)
                    .execute()
                
                completion(nil)
            } catch {
                print("Error unliking post: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Posted Place Checks
    
    func getPostedPlaceIds(userId: String, placeIds: [String]) async throws -> Set<String> {
        guard !placeIds.isEmpty else { return [] }
        
        struct Params: Encodable {
            let p_user_id: String
            let p_place_ids: [String]
        }
        
        let params = Params(p_user_id: userId, p_place_ids: placeIds)
        
        let postedIds: [String] = try await supabase.client
            .rpc("get_user_reviewed_place_ids", params: params)
            .execute()
            .value
        
        return Set(postedIds)
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
    
    // MARK: - Helper Methods
    
    private func parseTimestamp(_ timestampString: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try different formats
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: timestampString) {
                return date
            }
        }
        
        return Date()
    }
    
    /// Parses TikTok data from the database into TikTokVideo objects.
    /// The database returns basic info; full metadata is fetched on-demand via TikTokMetadataCache.
    private func parseTikTokData(_ tiktokData: [[String: Any]]) -> [TikTokVideo] {
        return tiktokData.compactMap { dict -> TikTokVideo? in
            guard let videoUrl = dict["url"] as? String, !videoUrl.isEmpty else {
                return nil
            }

            // Extract video ID from URL or use external_place_id as fallback
            let videoId = extractVideoIdFromTikTokURL(videoUrl) ?? (dict["external_place_id"] as? String ?? UUID().uuidString)

            // Build author from saved_by fields (the user who saved this TikTok)
            let savedByFirstName = dict["saved_by_first_name"] as? String ?? ""
            let savedByLastName = dict["saved_by_last_name"] as? String ?? ""
            let displayName = [savedByFirstName, savedByLastName].filter { !$0.isEmpty }.joined(separator: " ")

            let author = TikTokAuthor(
                displayName: displayName,
                url: "",
                username: ""
            )

            var video = TikTokVideo(
                videoID: videoId,
                url: videoUrl,
                title: nil,
                caption: nil,
                embedHTML: "",
                thumbnailURL: "", // Fetched on-demand via TikTokMetadataCache
                author: author,
                hashtags: [],
                createdAt: dict["added_at"] as? String ?? ""
            )

            // Attach saved_by info for display
            video.savedByUserId = dict["saved_by_user_id"] as? String
            video.externalPlaceId = dict["external_place_id"] as? String

            return video
        }
    }

    /// Extracts video ID from a TikTok URL.
    private func extractVideoIdFromTikTokURL(_ url: String) -> String? {
        let patterns = [
            "/photo/([0-9]+)",
            "/video/([0-9]+)",
            "@[^/]+/video/([0-9]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(location: 0, length: url.count)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }

        return nil
    }
}

// MARK: - Data Records

struct PostRecord: Codable {
    let id: String
    let place_id: String
    let user_id: String
    let user_first_name: String?
    let user_last_name: String?
    let profile_photo_url: String?
    let place_name: String?
    let review_text: String?
    let images: [String]?
    let timestamp: Date
    let likes: Int?
    let type: String?
    let would_return: Bool?
}

struct PostWithUserRecord: Codable {
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
    let tiktok_videos: [AnyCodable]?
    let would_return: Bool?
}

