//
//  PostService.swift
//  loc
//
//  Service for managing place posts - delegates to SupabasePostService
//  Single Responsibility: Orchestrates post operations and ensures data integrity
//

import Foundation

class PostService: ObservableObject {
    nonisolated(unsafe) static let shared = PostService()
    private let supabase = SupabasePostService.shared
    private let placeService: SupabasePlaceService
    
    private init(placeService: SupabasePlaceService = .shared) {
        self.placeService = placeService
    }
    
    // MARK: - Fetch Posts
    
    func fetchPosts(placeId: String, latestOnly: Bool = false) async throws -> ([PlacePost], [ExternalVideo]) {
        return try await supabase.fetchPlacePosts(placeId: placeId, latestOnly: latestOnly)
    }
    
    func fetchUserPosts(userId: String) async throws -> [PlacePost] {
        return try await supabase.fetchUserPosts(userId: userId)
    }
    
    // MARK: - Save Post
    
    /// Saves a post, ensuring the associated place exists in the database first.
    /// This handles the foreign key constraint on reviews.place_id automatically.
    func savePost(_ post: PlacePost, forPlace place: DetailPlace, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                // Ensure place exists before saving post (satisfies FK constraint)
                try await placeService.ensurePlaceExists(place: place)
                
                // Now save the post
                supabase.savePost(post: post) { error in
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
    }
    
    /// Legacy method for saving posts when place is already guaranteed to exist
    @available(*, deprecated, message: "Use savePost(_:forPlace:) to ensure place exists")
    func savePost(_ post: PlacePost, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            supabase.savePost(post: post) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Delete Post
    
    func deletePost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            supabase.deletePost(postId: postId) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Likes
    
    func likePost(userId: String, placeId: String, postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            supabase.likePost(postId: postId, userId: userId) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    func unlikePost(userId: String, placeId: String, postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            supabase.unlikePost(postId: postId, userId: userId) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    func togglePostLike(userId: String, placeId: String, postId: String, currentlyLiked: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        if currentlyLiked {
            unlikePost(userId: userId, placeId: placeId, postId: postId) { result in
                switch result {
                case .success:
                    completion(.success(false))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            likePost(userId: userId, placeId: placeId, postId: postId) { result in
                switch result {
                case .success:
                    completion(.success(true))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - User Feed

    /// Fetches the photo feed for a user (reviews with photos from followed users and self).
    func fetchUserFeed(userId: String, limit: Int = 50, offset: Int = 0) async throws -> [FeedItem] {
        return try await supabase.fetchUserFeed(userId: userId, limit: limit, offset: offset)
    }

    // MARK: - Reviewed Place Checks
    
    func getPostedPlaceIds(userId: String, placeIds: [String]) async throws -> Set<String> {
        return try await supabase.getPostedPlaceIds(userId: userId, placeIds: placeIds)
    }
    
    // MARK: - External Review Media

    func fetchExternalReviewMedia(placeId: String, reviewOffset: Int, reviewLimit: Int) async throws -> (urls: [String], nextReviewOffset: Int, hasMore: Bool) {
        return try await supabase.fetchExternalReviewMedia(placeId: placeId, reviewOffset: reviewOffset, reviewLimit: reviewLimit)
    }

    /// Deletes a specific image from external reviews for a place.
    func deleteExternalReviewImage(placeId: String, imageUrl: String) async throws {
        try await supabase.deleteExternalReviewImage(placeId: placeId, imageUrl: imageUrl)
    }
}

