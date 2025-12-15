//
//  PostService.swift
//  loc
//
//  Service for managing place posts - delegates to SupabasePostService
//

import Foundation

class PostService: ObservableObject {
    static let shared = PostService()
    private let supabase = SupabasePostService.shared
    
    private init() {}
    
    // MARK: - Fetch Posts
    
    func fetchPosts(placeId: String, latestOnly: Bool = false) async throws -> ([PlacePost], [TikTokVideo]) {
        return try await supabase.fetchPlacePosts(placeId: placeId, latestOnly: latestOnly)
    }
    
    func fetchUserPosts(userId: String) async throws -> [PlacePost] {
        return try await supabase.fetchUserPosts(userId: userId)
    }
    
    // MARK: - Save Post
    
    func savePost(_ post: PlacePost, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            await supabase.savePost(post: post) { error in
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
            await supabase.deletePost(postId: postId) { error in
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
            await supabase.likePost(postId: postId, userId: userId) { error in
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
            await supabase.unlikePost(postId: postId, userId: userId) { error in
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
    
    // MARK: - Reviewed Place Checks
    
    func getPostedPlaceIds(userId: String, placeIds: [String]) async throws -> Set<String> {
        return try await supabase.getPostedPlaceIds(userId: userId, placeIds: placeIds)
    }
    
    // MARK: - External Review Media
    
    func fetchExternalReviewMedia(placeId: String, reviewOffset: Int, reviewLimit: Int) async throws -> (urls: [String], nextReviewOffset: Int, hasMore: Bool) {
        return try await supabase.fetchExternalReviewMedia(placeId: placeId, reviewOffset: reviewOffset, reviewLimit: reviewLimit)
    }
}

