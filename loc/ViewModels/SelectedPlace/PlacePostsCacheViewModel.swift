//
//  PlacePostsCacheViewModel.swift
//  loc
//
//  Manages posts and TikToks caching, loading states, and like tracking.
//  Single Responsibility: Only handles post/TikTok data management.
//

import Foundation

@MainActor
class PlacePostsCacheViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Increments whenever posts are modified - allows observers to react to post changes.
    @Published private(set) var postsUpdateCounter: Int = 0

    /// Whether the current place is fully loaded.
    @Published var isCurrentPlaceFullyLoaded: Bool = false

    // MARK: - Private Storage

    /// Cache for posts by placeId.
    private var placePosts: [String: [PlacePost]] = [:]

    /// Cache for TikToks by placeId.
    private var placeTikToks: [String: [TikTokVideo]] = [:]

    /// Loading states for posts by placeId.
    private var postLoadingStates: [String: LoadingState] = [:]

    /// Set of liked post IDs.
    private var likedPosts: Set<String> = []

    // MARK: - Dependencies

    private let postService: PostService

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

    /// Initializes with required services.
    init(postService: PostService) {
        self.postService = postService
    }

    // MARK: - Public Accessors

    /// Returns posts for a specific place.
    func posts(forPlaceId placeId: String) -> [PlacePost] {
        return placePosts[placeId] ?? []
    }

    /// Returns TikToks for a specific place.
    func tiktoks(forPlaceId placeId: String) -> [TikTokVideo] {
        return placeTikToks[placeId] ?? []
    }

    /// Returns the loading state for posts of a specific place.
    func postLoadingState(forPlaceId placeId: String) -> LoadingState {
        return postLoadingStates[placeId] ?? .idle
    }

    /// Returns whether a post is liked.
    func isPostLiked(_ postId: String) -> Bool {
        return likedPosts.contains(postId)
    }

    /// Gets a post by its ID from any cached place.
    func getPost(by postId: String) -> PlacePost? {
        for posts in placePosts.values {
            if let post = posts.first(where: { $0.id == postId }) {
                return post
            }
        }
        return nil
    }

    // MARK: - Loading Methods

    /// Loads posts and TikToks for a place.
    func loadPosts(forPlaceId placeId: String) {
        postLoadingStates[placeId] = .loading
        objectWillChange.send()

        Task {
            guard let currentUserId = SupabaseAuthService.shared.currentUserId else {
                self.postLoadingStates[placeId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
                self.setPostsAndNotify(placeId: placeId, posts: [], tiktoks: [])
                self.updateLoadingState(forPlaceId: placeId)
                return
            }

            await loadPostsInternal(placeId: placeId, currentUserId: currentUserId)
        }
    }

    /// Loads posts with a specific user ID.
    private func loadPostsInternal(placeId: String, currentUserId: String) async {
        do {
            let (posts, tiktoks) = try await postService.fetchPosts(placeId: placeId, latestOnly: false)

            self.setPostsAndNotify(placeId: placeId, posts: posts, tiktoks: tiktoks)
            self.postLoadingStates[placeId] = .loaded
            self.updateLoadingState(forPlaceId: placeId)
        } catch {
            print("❌ [PlacePostsCacheVM] Error fetching posts/TikToks for place \(placeId): \(error.localizedDescription)")
            self.postLoadingStates[placeId] = .error(error)
            self.setPostsAndNotify(placeId: placeId, posts: [], tiktoks: [])
            self.updateLoadingState(forPlaceId: placeId)
        }
    }

    // MARK: - Mutation Methods

    /// Adds a new post to a place's cache.
    func addPost(_ post: PlacePost, forPlaceId placeId: String) {
        var currentPosts = placePosts[placeId] ?? []
        currentPosts.insert(post, at: 0)
        setPostsAndNotify(placeId: placeId, posts: currentPosts)
    }

    /// Deletes a post from cache and database.
    func deletePost(postId: String, forPlaceId placeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard placePosts[placeId]?.contains(where: { $0.id == postId }) == true else {
            completion(.failure(NSError(domain: "PlacePostsCacheViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post not found in cache"])))
            return
        }

        postService.deletePost(postId: postId) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                var currentPosts = self.placePosts[placeId] ?? []
                currentPosts.removeAll { $0.id == postId }
                self.likedPosts.remove(postId)
                self.setPostsAndNotify(placeId: placeId, posts: currentPosts)
                completion(.success(()))

            case .failure(let error):
                print("❌ [PlacePostsCacheVM] Failed to delete post: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Like Management

    /// Clears liked posts for a fresh place.
    func clearLikedPosts() {
        likedPosts.removeAll()
    }

    /// Marks a post as liked.
    func markPostLiked(_ postId: String) {
        likedPosts.insert(postId)
    }

    /// Marks a post as unliked.
    func markPostUnliked(_ postId: String) {
        likedPosts.remove(postId)
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

    /// Sets posts and notifies observers.
    private func setPostsAndNotify(placeId: String, posts: [PlacePost], tiktoks: [TikTokVideo]? = nil) {
        placePosts[placeId] = posts
        if let tiktoks = tiktoks {
            placeTikToks[placeId] = tiktoks
        }
        postsUpdateCounter += 1
        objectWillChange.send()
    }

    /// Updates the loading state for a specific place.
    private func updateLoadingState(forPlaceId placeId: String) {
        let postState = postLoadingStates[placeId] ?? .idle

        let postsReady: Bool
        switch postState {
        case .loaded, .error:
            postsReady = true
        case .idle, .loading:
            postsReady = false
        }

        isCurrentPlaceFullyLoaded = postsReady
        objectWillChange.send()
    }

    // MARK: - Cleanup

    /// Clears all cached data.
    func clearAllData() {
        placePosts.removeAll()
        placeTikToks.removeAll()
        postLoadingStates.removeAll()
        likedPosts.removeAll()
        postsUpdateCounter = 0
        isCurrentPlaceFullyLoaded = false
    }
}
