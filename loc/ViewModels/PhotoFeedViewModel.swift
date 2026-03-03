//
//  PhotoFeedViewModel.swift
//  loc
//
//  ViewModel for the photo feed — handles loading, pagination, and card flip state.
//  Single Responsibility: Manage feed data lifecycle and UI state for photo feed.
//

import Foundation

@MainActor
class PhotoFeedViewModel: ObservableObject {
    // MARK: - Published State

    @Published var feedItems: [FeedItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = true
    @Published var flippedCardId: String?
    @Published var currentUserProfile: ProfileData?

    // MARK: - Dependencies

    private let postService = ServiceContainer.shared.postService
    private let userService = ServiceContainer.shared.userService
    private let userId: String
    private let pageSize = 50

    // MARK: - Private State

    private var currentOffset = 0

    // MARK: - Initialization

    /// Initializes the feed view model for a specific user.
    init(userId: String) {
        self.userId = userId
    }

    // MARK: - Public Methods

    /// Loads the first page of the photo feed and fetches the current user profile.
    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        currentOffset = 0

        async let profileFetch: () = loadCurrentUserProfile()

        do {
            let items = try await postService.fetchUserFeed(
                userId: userId,
                limit: pageSize,
                offset: 0
            )
            feedItems = items
            hasMorePages = items.count == pageSize
            currentOffset = items.count
        } catch {
            print("[PhotoFeedViewModel] Failed to load feed: \(error)")
        }

        await profileFetch
        isLoading = false
    }

    /// Loads the next page of feed items when scrolling near the end.
    func loadMoreIfNeeded(currentItem: FeedItem) async {
        guard hasMorePages, !isLoadingMore else { return }

        let thresholdIndex = max(feedItems.count - 5, 0)
        guard let currentIndex = feedItems.firstIndex(where: { $0.id == currentItem.id }),
              currentIndex >= thresholdIndex else {
            return
        }

        isLoadingMore = true

        do {
            let items = try await postService.fetchUserFeed(
                userId: userId,
                limit: pageSize,
                offset: currentOffset
            )
            feedItems.append(contentsOf: items)
            hasMorePages = items.count == pageSize
            currentOffset += items.count
        } catch {
            print("[PhotoFeedViewModel] Failed to load more: \(error)")
        }

        isLoadingMore = false
    }

    /// Toggles the flip state for a feed card (only one card flipped at a time).
    func toggleFlip(for itemId: String) {
        if flippedCardId == itemId {
            flippedCardId = nil
        } else {
            flippedCardId = itemId
        }
    }

    /// Updates the local comment count for a feed item after the comments sheet is dismissed.
    func updateCommentCount(for itemId: String, count: Int) {
        guard let index = feedItems.firstIndex(where: { $0.id == itemId }) else { return }
        feedItems[index].commentCount = count
    }

    /// Resets and reloads the feed from the beginning.
    func refresh() async {
        flippedCardId = nil
        currentOffset = 0
        hasMorePages = true

        do {
            let items = try await postService.fetchUserFeed(
                userId: userId,
                limit: pageSize,
                offset: 0
            )
            feedItems = items
            hasMorePages = items.count == pageSize
            currentOffset = items.count
        } catch {
            print("[PhotoFeedViewModel] Failed to refresh feed: \(error)")
        }
    }

    // MARK: - Private Methods

    /// Fetches the current user's profile data for use in comment authoring.
    private func loadCurrentUserProfile() async {
        do {
            currentUserProfile = try await userService.fetchUserById(userId: userId)
        } catch {
            print("[PhotoFeedViewModel] Failed to load user profile: \(error)")
        }
    }
}
