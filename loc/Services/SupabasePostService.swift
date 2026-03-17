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
    
    private nonisolated init() {}
    
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
                    video_urls: post.videoUrls.isEmpty ? nil : post.videoUrls,
                    video_thumbnail_urls: post.videoThumbnailUrls.isEmpty ? nil : post.videoThumbnailUrls,
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
    
    func fetchPlacePosts(placeId: String, latestOnly: Bool = false) async throws -> ([PlacePost], [ExternalVideo]) {
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
        
        // Fetch external videos separately
        struct ExternalVideoArrayRecord: Codable {
            let tiktok_videos: [AnyCodable]?
        }

        let externalVideoResponse: [ExternalVideoArrayRecord] = try await supabase.client
            .rpc("get_place_tiktoks", params: ["p_place_id": placeUUID])
            .execute()
            .value

        var externalVideos: [ExternalVideo] = []

        if let firstRecord = externalVideoResponse.first,
           let externalVideoArray = firstRecord.tiktok_videos {
            let externalVideoData = externalVideoArray.compactMap { $0.value as? [String: Any] }
            externalVideos = parseExternalVideoData(externalVideoData)
        }

        if response.isEmpty {
            return ([], externalVideos)
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
                text: record.review_text ?? "",
                timestamp: timestamp,
                images: record.review_images ?? [],
                videoUrls: record.review_video_urls ?? [],
                videoThumbnailUrls: record.review_video_thumbnails ?? [],
                likes: record.review_likes ?? 0,
                commentCount: record.review_comment_count ?? 0,
                wouldReturn: record.would_return
            )
        }
        
        if latestOnly && !posts.isEmpty {
            return ([posts[0]], externalVideos)
        }

        return (posts, externalVideos)
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
                videoUrls: record.video_urls ?? [],
                videoThumbnailUrls: record.video_thumbnail_urls ?? [],
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
    
    // MARK: - Delete External Review Image

    /// Deletes a specific image from external reviews for a place via RPC.
    func deleteExternalReviewImage(placeId: String, imageUrl: String) async throws {
        try await supabase.client
            .rpc("delete_external_review_image", params: [
                "p_place_id": placeId,
                "p_image_url": imageUrl
            ])
            .execute()
    }

    // MARK: - Comments

    /// Fetches comments for a review, joined with user info.
    func fetchComments(reviewId: String) async throws -> [Comment] {
        let response: [CommentWithUserRecord] = try await supabase.client
            .from("comments")
            .select("id, review_id, user_id, text, images, likes, timestamp, users:user_id(first_name, last_name, profile_photo_url)")
            .eq("review_id", value: reviewId)
            .order("timestamp", ascending: true)
            .execute()
            .value

        return response.map { record in
            Comment(
                id: record.id,
                reviewId: record.review_id,
                userId: record.user_id,
                profilePhotoUrl: record.users?.profile_photo_url ?? "",
                userFirstName: record.users?.first_name ?? "",
                userLastName: record.users?.last_name ?? "",
                commentText: record.text,
                timestamp: record.timestamp,
                images: record.images ?? [],
                likes: record.likes ?? 0
            )
        }
    }

    /// Adds a comment to a review and returns the created Comment.
    func addComment(reviewId: String, placeId: String, userId: String, text: String, userFirstName: String, userLastName: String, profilePhotoUrl: String) async throws -> Comment {
        let commentId = UUID().uuidString
        let now = Date()

        let insertRecord = CommentInsertRecord(
            id: commentId,
            review_id: reviewId,
            place_id: placeId,
            user_id: userId,
            text: text,
            images: [],
            likes: 0,
            timestamp: now
        )

        try await supabase.client
            .from("comments")
            .insert(insertRecord)
            .execute()

        return Comment(
            id: commentId,
            reviewId: reviewId,
            userId: userId,
            profilePhotoUrl: profilePhotoUrl,
            userFirstName: userFirstName,
            userLastName: userLastName,
            commentText: text,
            timestamp: now,
            images: [],
            likes: 0
        )
    }

    /// Deletes a comment by its ID.
    func deleteComment(commentId: String) async throws {
        try await supabase.client
            .from("comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
    }

    // MARK: - User Feed

    /// Fetches the photo feed for a user (reviews with photos from followed users and self).
    func fetchUserFeed(userId: String, limit: Int = 50, offset: Int = 0) async throws -> [FeedItem] {
        struct Params: Encodable {
            let p_user_id: String
            let p_limit: Int
            let p_offset: Int
        }

        let params = Params(p_user_id: userId, p_limit: limit, p_offset: offset)

        let records: [FeedItemRecord] = try await supabase.client
            .rpc("get_user_feed", params: params)
            .execute()
            .value

        return records.compactMap { record -> FeedItem? in
            let validUrls = (record.images ?? []).filter { !$0.isEmpty }
            guard !validUrls.isEmpty else { return nil }

            let timestamp = parseTimestamp(record.review_timestamp)

            return FeedItem(
                id: record.review_id,
                userId: record.user_id,
                userFirstName: record.user_first_name ?? "",
                userLastName: record.user_last_name ?? "",
                profilePhotoUrl: record.profile_photo_url ?? "",
                placeId: record.place_id,
                placeName: record.place_name ?? "",
                caption: record.review_text ?? "",
                imageUrls: validUrls,
                timestamp: timestamp,
                likes: record.likes ?? 0,
                commentCount: record.comment_count ?? 0,
                wouldReturn: record.would_return,
                latitude: record.latitude ?? 0,
                longitude: record.longitude ?? 0
            )
        }
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
    
    /// Parses external video data from the database into ExternalVideo objects.
    /// The database returns basic info; full metadata is fetched on-demand via ExternalMetadataCache.
    private func parseExternalVideoData(_ videoData: [[String: Any]]) -> [ExternalVideo] {
        return videoData.compactMap { dict -> ExternalVideo? in
            guard let videoUrl = dict["url"] as? String, !videoUrl.isEmpty else {
                return nil
            }

            // Extract video ID from URL or use external_place_id as fallback
            let videoId = extractVideoIdFromURL(videoUrl) ?? (dict["external_place_id"] as? String ?? UUID().uuidString)

            // Build author from saved_by fields (the user who saved this video)
            let savedByFirstName = dict["saved_by_first_name"] as? String ?? ""
            let savedByLastName = dict["saved_by_last_name"] as? String ?? ""
            let displayName = [savedByFirstName, savedByLastName].filter { !$0.isEmpty }.joined(separator: " ")

            let author = ExternalVideoAuthor(
                displayName: displayName,
                url: "",
                username: ""
            )

            let detectedContentType = videoUrl.contains("/photo/") ? "photo" : "video"
            var video = ExternalVideo(
                videoID: videoId,
                url: videoUrl,
                title: nil,
                caption: nil,
                embedHTML: "",
                thumbnailURL: "", // Fetched on-demand via ExternalMetadataCache

                author: author,
                hashtags: [],
                createdAt: dict["added_at"] as? String ?? "",
                contentType: detectedContentType
            )

            // Attach saved_by info for display
            video.savedByUserId = dict["saved_by_user_id"] as? String
            video.externalPlaceId = dict["external_place_id"] as? String

            return video
        }
    }

    /// Extracts video ID from an external video URL (TikTok or Instagram).
    private func extractVideoIdFromURL(_ url: String) -> String? {
        let patterns = [
            "/photo/([0-9]+)",
            "/video/([0-9]+)",
            "@[^/]+/video/([0-9]+)",
            "/reel/([\\w-]+)",
            "/reels/([\\w-]+)",
            "/p/([\\w-]+)"
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
    let video_urls: [String]?
    let video_thumbnail_urls: [String]?
    let timestamp: Date
    let likes: Int?
    let type: String?
    let would_return: Bool?
}

struct PostWithUserRecord: Codable {
    let review_id: String
    let review_user_id: String
    let review_text: String?
    let review_images: [String]?
    let review_timestamp: String
    let review_type: String?
    let review_likes: Int?
    let user_first_name: String?
    let user_last_name: String?
    let user_profile_photo_url: String?
    let tiktok_videos: [AnyCodable]?
    let would_return: Bool?
    let review_video_urls: [String]?
    let review_video_thumbnails: [String]?
    let review_comment_count: Int?
}

// MARK: - Feed Records

struct FeedItemRecord: Codable {
    let review_id: String
    let user_id: String
    let user_first_name: String?
    let user_last_name: String?
    let profile_photo_url: String?
    let place_id: String
    let place_name: String?
    let review_text: String?
    let images: [String]?
    let review_timestamp: String
    let likes: Int?
    let would_return: Bool?
    let latitude: Double?
    let longitude: Double?
    let comment_count: Int?
}

// MARK: - Comment Records

struct CommentUserRecord: Codable {
    let first_name: String?
    let last_name: String?
    let profile_photo_url: String?
}

struct CommentWithUserRecord: Codable {
    let id: String
    let review_id: String
    let user_id: String
    let text: String
    let images: [String]?
    let likes: Int?
    let timestamp: Date
    let users: CommentUserRecord?
}

struct CommentInsertRecord: Codable {
    let id: String
    let review_id: String
    let place_id: String
    let user_id: String
    let text: String
    let images: [String]
    let likes: Int
    let timestamp: Date
}

