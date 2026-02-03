//
//  PlacePostsCacheService.swift
//  loc
//
//  Singleton service for managing posts and TikToks caching, loading states, and like tracking.
//  Single Responsibility: Only handles post/TikTok data management.
//  ViewModels subscribe to this service via Combine to react to cache changes.
//

import Foundation
import Combine

@MainActor
class PlacePostsCacheService: ObservableObject {
    static let shared = PlacePostsCacheService()

    // MARK: - Published Properties (ViewModels subscribe to these)

    /// Cache for posts by placeId - published so subscribers get updates.
    @Published private(set) var postsCache: [String: [PlacePost]] = [:]

    /// Cache for TikToks by placeId - published so subscribers get updates.
    @Published private(set) var tiktoksCache: [String: [TikTokVideo]] = [:]

    /// Loading states for posts by placeId - published so subscribers get updates.
    @Published private(set) var loadingStates: [String: LoadingState] = [:]

    /// Set of liked post IDs - published so subscribers get updates.
    @Published private(set) var likedPostIds: Set<String> = []

    // MARK: - Dependencies

    private var postService: PostService { ServiceContainer.shared.postService }
    private var authService: SupabaseAuthService { ServiceContainer.shared.authService }

    // MARK: - Loading State Enum

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(Error)

        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.error, .error):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern.
    private init() {}

    // MARK: - Public Accessors

    /// Returns posts for a specific place.
    func posts(forPlaceId placeId: String) -> [PlacePost] {
        return postsCache[placeId] ?? []
    }

    /// Returns TikToks for a specific place.
    func tiktoks(forPlaceId placeId: String) -> [TikTokVideo] {
        return tiktoksCache[placeId] ?? []
    }

    /// Returns the loading state for posts of a specific place.
    func loadingState(forPlaceId placeId: String) -> LoadingState {
        return loadingStates[placeId] ?? .idle
    }

    /// Returns whether a post is liked.
    func isPostLiked(_ postId: String) -> Bool {
        return likedPostIds.contains(postId)
    }

    /// Returns whether posts are fully loaded for a specific place.
    func isFullyLoaded(forPlaceId placeId: String) -> Bool {
        let state = loadingStates[placeId] ?? .idle
        switch state {
        case .loaded, .error:
            return true
        case .idle, .loading:
            return false
        }
    }

    /// Gets a post by its ID from any cached place.
    func getPost(by postId: String) -> PlacePost? {
        for posts in postsCache.values {
            if let post = posts.first(where: { $0.id == postId }) {
                return post
            }
        }
        return nil
    }

    // MARK: - Loading Methods

    /// Loads posts and TikToks for a place.
    func loadPosts(forPlaceId placeId: String) {
        loadingStates[placeId] = .loading
        objectWillChange.send()

        Task {
            guard let currentUserId = authService.currentUserId else {
                self.loadingStates[placeId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
                self.updateCache(placeId: placeId, posts: [], tiktoks: [])
                return
            }

            await loadPostsInternal(placeId: placeId)
        }
    }

    /// Fetches posts from the service and updates the cache.
    private func loadPostsInternal(placeId: String) async {
        do {
            let (posts, tiktoks) = try await postService.fetchPosts(placeId: placeId, latestOnly: false)

            self.updateCache(placeId: placeId, posts: posts, tiktoks: tiktoks)
            self.loadingStates[placeId] = .loaded
        } catch {
            print("❌ [PlacePostsCacheService] Error fetching posts/TikToks for place \(placeId): \(error.localizedDescription)")
            self.loadingStates[placeId] = .error(error)
            self.updateCache(placeId: placeId, posts: [], tiktoks: [])
        }
    }

    // MARK: - Mutation Methods

    /// Adds a new post to a place's cache.
    func addPost(_ post: PlacePost, forPlaceId placeId: String) {
        var currentPosts = postsCache[placeId] ?? []
        currentPosts.insert(post, at: 0)
        updateCache(placeId: placeId, posts: currentPosts)
    }

    /// Deletes a post from cache and database.
    func deletePost(postId: String, forPlaceId placeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard postsCache[placeId]?.contains(where: { $0.id == postId }) == true else {
            completion(.failure(NSError(domain: "PlacePostsCacheService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post not found in cache"])))
            return
        }

        postService.deletePost(postId: postId) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                var currentPosts = self.postsCache[placeId] ?? []
                currentPosts.removeAll { $0.id == postId }
                self.likedPostIds.remove(postId)
                self.updateCache(placeId: placeId, posts: currentPosts)
                completion(.success(()))

            case .failure(let error):
                print("❌ [PlacePostsCacheService] Failed to delete post: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Like Management

    /// Clears liked posts for a fresh place.
    func clearLikedPosts() {
        likedPostIds.removeAll()
    }

    /// Marks a post as liked.
    func markPostLiked(_ postId: String) {
        likedPostIds.insert(postId)
    }

    /// Marks a post as unliked.
    func markPostUnliked(_ postId: String) {
        likedPostIds.remove(postId)
    }

    // MARK: - Formatting

    /// Formats a post's timestamp for display.
    func formattedTimestamp(for post: PlacePost) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: post.timestamp, to: now)

        if let minutes = components.minute, minutes < 60 && (components.hour ?? 0) == 0 && (components.day ?? 0) == 0 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if let hours = components.hour, hours < 24 && (components.day ?? 0) == 0 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: post.timestamp)
        }
    }

    // MARK: - Private Methods

    /// Updates the posts cache for a place. @Published properties automatically notify subscribers.
    private func updateCache(placeId: String, posts: [PlacePost], tiktoks: [TikTokVideo]? = nil) {
        postsCache[placeId] = posts
        if let tiktoks = tiktoks {
            tiktoksCache[placeId] = tiktoks
        }
    }

    // MARK: - Cleanup

    /// Clears all cached data.
    func clearAllData() {
        postsCache.removeAll()
        tiktoksCache.removeAll()
        loadingStates.removeAll()
        likedPostIds.removeAll()
    }
}
