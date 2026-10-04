//
//  CommentsCacheService.swift
//  loc
//
//  Shared, app-wide cache for review comments, keyed by reviewId. Reopening the same
//  review's comment sheet renders instantly from cache instead of re-fetching from
//  network every time.
//

import Foundation

@MainActor
class CommentsCacheService: ObservableObject {
    static let shared = CommentsCacheService()

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
    }

    @Published private(set) var commentsCache: [String: [Comment]] = [:]
    @Published private(set) var loadingStates: [String: LoadingState] = [:]

    private var postService: SupabasePostService { ServiceContainer.shared.supabasePostService }

    private init() {}

    /// Whether this review's comments have already been fetched at least once this session.
    func isCached(forReviewId reviewId: String) -> Bool {
        commentsCache[reviewId] != nil
    }

    func loadingState(forReviewId reviewId: String) -> LoadingState {
        loadingStates[reviewId] ?? .idle
    }

    /// Fetches comments for a review from network and updates the cache. Callers that already
    /// have a cached value should show it immediately and call this to refresh in the background.
    func loadComments(reviewId: String) async {
        let alreadyCached = isCached(forReviewId: reviewId)
        if !alreadyCached {
            loadingStates[reviewId] = .loading
        }
        do {
            commentsCache[reviewId] = try await postService.fetchComments(reviewId: reviewId)
        } catch {
            print("Failed to fetch comments for review \(reviewId): \(error)")
        }
        loadingStates[reviewId] = .loaded
    }

    /// Appends a newly-created comment to the cache for immediate display.
    func addComment(_ comment: Comment, toReviewId reviewId: String) {
        commentsCache[reviewId, default: []].append(comment)
    }

    /// Removes a deleted comment from the cache.
    func removeComment(commentId: String, fromReviewId reviewId: String) {
        commentsCache[reviewId]?.removeAll { $0.id == commentId }
    }
}
