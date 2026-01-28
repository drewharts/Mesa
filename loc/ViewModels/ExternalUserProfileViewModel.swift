//
//  ExternalUserProfileViewModel.swift
//  loc
//
//  Created for Instagram-style nested profile navigation.
//  Each profile in the navigation stack gets its own independent ViewModel instance.
//

import Foundation
import SwiftUI

/// ViewModel for external user profiles that is instantiated per-view using @StateObject.
/// This enables Instagram-style nested navigation where each profile maintains its own state.
@MainActor
class ExternalUserProfileViewModel: ObservableObject {
    // MARK: - Core Identity (set at init, immutable)
    let userId: String
    @Published var user: ProfileData

    // MARK: - Profile Data
    @Published var userFavorites: [FavoritePlace] = []
    @Published var userLists: [LightweightPlaceList] = []
    @Published var placeListPlaces: [String: [LightweightPlace]] = [:]
    @Published var lightweightReviewedPlaces: [LightweightPlace] = []

    // MARK: - Social State
    @Published var isFollowing: Bool = false
    @Published var followers: Int = 0
    @Published var followingCount: Int = 0
    @Published var totalPlacesCount: Int = 0

    // MARK: - Followers/Following for Nested Navigation
    @Published var externalUserFollowers: [ProfileData] = []
    @Published var externalUserFollowing: [ProfileData] = []

    // MARK: - Loading States
    @Published var isLoadingFavorites = false
    @Published var isLoadingReviewedPlaces = false
    @Published var isLoadingMoreReviews = false
    @Published var isExternalFollowersLoading = false
    @Published var isExternalFollowingLoading = false
    @Published var hasMoreExternalFollowers = true
    @Published var hasMoreExternalFollowing = true
    @Published var hasMoreReviews = true
    @Published var totalReviewedPlacesCount: Int = 0

    // MARK: - List Pagination State
    @Published var isLoadingMoreLists = false
    private var currentListPage: Int = 1
    private var hasMoreLists: Bool = true
    private let listsPerPage: Int = 6
    private var loadedListIds: Set<String> = []
    private var loadingListIds: Set<String> = []

    // MARK: - Deep Link List Popup State
    @Published var shouldShowListPopup = false
    @Published var pendingListIndex: Int?
    private var pendingListIdToOpen: String?

    // MARK: - Error Handling
    @Published var showFollowError = false
    @Published var followErrorMessage = ""

    // MARK: - Services (from ServiceContainer.shared)
    private let userService: UserService
    private let placeService: PlaceService
    private let postService: PostService

    // MARK: - Pagination Constants
    private let followersPerPage: Int = 20
    private let reviewsPerPage: Int = 8

    // MARK: - Favorites as LightweightPlace
    var lightweightFavorites: [LightweightPlace] {
        userFavorites.map { favorite in
            LightweightPlace(
                place_id: favorite.place_id,
                name: favorite.name,
                latest_review_photo: favorite.latest_review_photo,
                external_place_id: nil,
                tiktok_url: nil,
                added_by_user_id: nil,
                added_by_name: nil,
                added_by_photo_url: nil
            )
        }
    }

    // MARK: - Initialization

    /// Creates a ViewModel for an external user profile.
    /// - Parameters:
    ///   - user: The user profile data
    ///   - pendingListId: Optional list ID to auto-open after data loads (for deep link navigation)
    init(user: ProfileData, pendingListId: String? = nil) {
        self.userId = user.id
        self.user = user
        self.pendingListIdToOpen = pendingListId
        self.userService = ServiceContainer.shared.userService
        self.placeService = ServiceContainer.shared.placeService
        self.postService = ServiceContainer.shared.postService
    }

    // MARK: - Initial Data Loading

    /// Loads all initial data for the profile. Called once when view appears.
    func loadInitialData(currentUserId: String) async {
        // Run all initial fetches in parallel
        async let followingCheck: () = checkIfFollowing(currentUserId: currentUserId)
        async let favoritesLoad: () = fetchProfileFavorites()
        async let listsLoad: () = fetchLists()
        async let followersLoad: () = fetchFollowers()
        async let followingCountLoad: () = fetchFollowingCount()
        async let placesCountLoad: () = fetchTotalPlacesCount()

        _ = await (followingCheck, favoritesLoad, listsLoad, followersLoad, followingCountLoad, placesCountLoad)
    }

    // MARK: - Following Status

    func checkIfFollowing(currentUserId: String) async {
        guard !userId.isEmpty else {
            isFollowing = false
            return
        }

        await withCheckedContinuation { continuation in
            userService.isFollowingUser(followerId: currentUserId, followingId: userId) { [weak self] isFollowing in
                Task { @MainActor in
                    self?.isFollowing = isFollowing
                    continuation.resume()
                }
            }
        }
    }

    func toggleFollowUser(currentUserId: String, completion: @escaping (Bool, Bool) -> Void) {
        let originalFollowingState = isFollowing
        let originalFollowersCount = followers

        if isFollowing {
            // Optimistic update
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isFollowing = false
                self.followers = max(0, self.followers - 1)
            }

            userService.unfollowUser(followerId: currentUserId, followingId: userId) { success, error in
                if !success {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isFollowing = originalFollowingState
                        self.followers = originalFollowersCount
                        self.showFollowError = true
                        self.followErrorMessage = "Failed to unfollow user. Please try again."
                    }
                    completion(false, originalFollowingState)
                } else {
                    completion(true, false)
                }
            }
        } else {
            // Optimistic update
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isFollowing = true
                self.followers += 1
            }

            userService.followUser(followerId: currentUserId, followingId: userId) { success, error in
                if success {
                    completion(true, true)
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isFollowing = originalFollowingState
                        self.followers = originalFollowersCount
                        self.showFollowError = true
                        self.followErrorMessage = "Failed to follow user. Please try again."
                    }
                    completion(false, originalFollowingState)
                }
            }
        }
    }

    // MARK: - Fetch Profile Data

    private func fetchProfileFavorites() async {
        isLoadingFavorites = true
        defer { isLoadingFavorites = false }

        do {
            let favorites = try await userService.fetchUserFavorites(userId: userId)
            self.userFavorites = favorites
        } catch {
            print("ExternalUserProfileViewModel Error fetching favorites: \(error)")
            self.userFavorites = []
        }
    }

    private func fetchLists() async {
        do {
            let lists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId,
                page: 1,
                pageSize: listsPerPage
            )

            self.userLists = lists
            self.currentListPage = 1
            self.hasMoreLists = lists.count >= self.listsPerPage

            // Check if there's a pending list to open (for deep links)
            await checkAndShowPendingList(lists: lists)

            // Preload places for first few visible lists
            await preloadPlacesForLists(Array(lists.prefix(3)))
        } catch {
            print("ExternalUserProfileViewModel Error fetching lists: \(error)")
            self.userLists = []
            self.hasMoreLists = false
            clearPendingListState()
        }
    }

    /// Checks if there's a pending list to open and triggers popup if found.
    private func checkAndShowPendingList(lists: [LightweightPlaceList]) async {
        guard let pendingListId = pendingListIdToOpen else { return }

        if let index = lists.firstIndex(where: { $0.list_id == pendingListId }) {
            // Found in current page - show popup
            await MainActor.run {
                self.pendingListIndex = index
                // Small delay to allow profile view to settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.shouldShowListPopup = true
                    self.pendingListIdToOpen = nil
                }
            }
        } else {
            // List not in first page - fetch it specifically
            await fetchAndShowSpecificList(listId: pendingListId)
        }
    }

    /// Fetches a specific list by ID and shows it (for deep links when list isn't in first page).
    private func fetchAndShowSpecificList(listId: String) async {
        do {
            guard let list = try await userService.fetchPlaceListById(listId: listId) else {
                print("ExternalUserProfileViewModel Could not find list with ID: \(listId)")
                await MainActor.run { self.clearPendingListState() }
                return
            }

            await MainActor.run {
                // Insert at the beginning so it appears first
                if !self.userLists.contains(where: { $0.list_id == listId }) {
                    self.userLists.insert(list, at: 0)
                }

                // Now find the index and show popup
                if let index = self.userLists.firstIndex(where: { $0.list_id == listId }) {
                    self.pendingListIndex = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.shouldShowListPopup = true
                        self.pendingListIdToOpen = nil
                    }
                } else {
                    self.clearPendingListState()
                }
            }
        } catch {
            print("ExternalUserProfileViewModel Error fetching specific list: \(error)")
            await MainActor.run { self.clearPendingListState() }
        }
    }

    /// Clears all pending list state.
    private func clearPendingListState() {
        pendingListIdToOpen = nil
        pendingListIndex = nil
        shouldShowListPopup = false
    }

    private func fetchFollowers() async {
        await withCheckedContinuation { continuation in
            userService.getNumberFollowers(forUserId: userId) { count, error in
                Task { @MainActor in
                    if error == nil {
                        self.followers = count
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func fetchFollowingCount() async {
        do {
            let count = try await userService.getNumberFollowing(forUserId: userId)
            self.followingCount = count
        } catch {
            print("ExternalUserProfileViewModel Error fetching following count: \(error)")
        }
    }

    private func fetchTotalPlacesCount() async {
        do {
            let count = try await userService.getTotalPlacesCount(forUserId: userId)
            self.totalPlacesCount = count
        } catch {
            print("ExternalUserProfileViewModel Error fetching total places count: \(error)")
        }
    }

    // MARK: - External Followers/Following Loading

    func loadExternalFollowers(offset: Int = 0) {
        let isInitialLoad = offset == 0
        if isInitialLoad {
            isExternalFollowersLoading = true
            externalUserFollowers = []
        }

        Task {
            do {
                let profiles = try await userService.fetchFollowerProfilesData(
                    for: userId,
                    limit: followersPerPage,
                    offset: offset
                )

                if isInitialLoad {
                    self.externalUserFollowers = profiles
                } else {
                    let existingIds = Set(self.externalUserFollowers.map { $0.id })
                    let newProfiles = profiles.filter { !existingIds.contains($0.id) }
                    self.externalUserFollowers.append(contentsOf: newProfiles)
                }
                self.hasMoreExternalFollowers = profiles.count >= self.followersPerPage
                self.isExternalFollowersLoading = false
            } catch {
                print("ExternalUserProfileViewModel Error loading external followers: \(error)")
                self.isExternalFollowersLoading = false
                self.hasMoreExternalFollowers = false
            }
        }
    }

    func loadExternalFollowing(offset: Int = 0) {
        let isInitialLoad = offset == 0
        if isInitialLoad {
            isExternalFollowingLoading = true
            externalUserFollowing = []
        }

        Task {
            do {
                let profiles = try await userService.fetchFollowingProfilesData(
                    for: userId,
                    limit: followersPerPage,
                    offset: offset
                )

                if isInitialLoad {
                    self.externalUserFollowing = profiles
                } else {
                    let existingIds = Set(self.externalUserFollowing.map { $0.id })
                    let newProfiles = profiles.filter { !existingIds.contains($0.id) }
                    self.externalUserFollowing.append(contentsOf: newProfiles)
                }
                self.hasMoreExternalFollowing = profiles.count >= self.followersPerPage
                self.isExternalFollowingLoading = false
            } catch {
                print("ExternalUserProfileViewModel Error loading external following: \(error)")
                self.isExternalFollowingLoading = false
                self.hasMoreExternalFollowing = false
            }
        }
    }

    // MARK: - Reviewed Places Loading

    func loadUserReviewedPlacesWithPagination() async {
        isLoadingReviewedPlaces = true
        defer { isLoadingReviewedPlaces = false }

        do {
            async let placesTask = userService.fetchUserReviewedPlaces(
                userId: userId,
                limit: reviewsPerPage,
                offset: 0
            )
            async let countTask = SupabaseUserService.shared.getNumberReviewedPlaces(forUserId: userId)

            let (places, totalCount) = try await (placesTask, countTask)

            lightweightReviewedPlaces = places
            totalReviewedPlacesCount = totalCount
            hasMoreReviews = !places.isEmpty && places.count >= reviewsPerPage

            // Prefetch TikTok metadata
            let tiktokUrls = places.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                }
            }
        } catch {
            print("ExternalUserProfileViewModel Error loading reviewed places: \(error)")
            hasMoreReviews = false
        }
    }

    func loadMoreReviews() async {
        guard !isLoadingMoreReviews, hasMoreReviews else { return }

        isLoadingMoreReviews = true
        defer { isLoadingMoreReviews = false }

        let offset = lightweightReviewedPlaces.count

        do {
            let places = try await userService.fetchUserReviewedPlaces(
                userId: userId,
                limit: reviewsPerPage,
                offset: offset
            )

            let existingIds = Set(lightweightReviewedPlaces.map { $0.id })
            let newUniquePlaces = places.filter { !existingIds.contains($0.id) }
            lightweightReviewedPlaces.append(contentsOf: newUniquePlaces)
            hasMoreReviews = !places.isEmpty && places.count >= reviewsPerPage

            // Prefetch TikTok metadata
            let tiktokUrls = places.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                }
            }
        } catch {
            print("ExternalUserProfileViewModel Error loading more reviewed places: \(error)")
            hasMoreReviews = false
        }
    }

    // MARK: - List Pagination

    func fetchMoreLists() {
        guard hasMoreLists, !isLoadingMoreLists else { return }

        isLoadingMoreLists = true
        let nextPage = currentListPage + 1

        Task {
            do {
                let newLists = try await userService.fetchPlaceListsWithoutLocation(
                    userId: userId,
                    page: nextPage,
                    pageSize: listsPerPage
                )

                self.userLists.append(contentsOf: newLists)
                self.currentListPage = nextPage
                self.hasMoreLists = newLists.count >= self.listsPerPage
                self.isLoadingMoreLists = false

                await preloadPlacesForLists(Array(newLists.prefix(3)))
            } catch {
                print("ExternalUserProfileViewModel Error fetching more lists: \(error)")
                self.isLoadingMoreLists = false
            }
        }
    }

    private func preloadPlacesForLists(_ lists: [LightweightPlaceList]) async {
        for list in lists {
            await loadPlacesForListAsync(listId: list.list_id)
        }
    }

    private func loadPlacesForListAsync(listId: String) async {
        guard placeListPlaces[listId] == nil else { return }

        do {
            let places = try await userService.fetchPlacesForPlaceList(
                listId: listId,
                page: 1,
                pageSize: 6
            )

            self.placeListPlaces[listId] = places
            self.loadedListIds.insert(listId)
        } catch {
            print("ExternalUserProfileViewModel Error loading places for list \(listId): \(error)")
        }
    }

    func loadPlacesForList(_ list: LightweightPlaceList) {
        Task {
            await loadPlacesForListAsync(listId: list.list_id)
        }
    }

    func loadMorePlacesForList(_ list: LightweightPlaceList, page: Int, completion: @escaping ([LightweightPlace]) -> Void) {
        Task {
            do {
                let morePlaces = try await userService.fetchPlacesForPlaceList(
                    listId: list.list_id,
                    page: page,
                    pageSize: 6
                )

                var existingPlaces = self.placeListPlaces[list.list_id] ?? []
                let existingIds = Set(existingPlaces.map { $0.id })
                let newUniquePlaces = morePlaces.filter { !existingIds.contains($0.id) }
                existingPlaces.append(contentsOf: newUniquePlaces)
                self.placeListPlaces[list.list_id] = existingPlaces

                completion(morePlaces)
            } catch {
                print("ExternalUserProfileViewModel Error loading more places for list: \(error)")
                completion([])
            }
        }
    }

    func preloadPlacesForVisibleLists() {
        let unloadedLists = userLists.filter {
            !loadedListIds.contains($0.list_id) && !loadingListIds.contains($0.list_id)
        }
        let listsToLoad = Array(unloadedLists.prefix(3))

        guard !listsToLoad.isEmpty else { return }

        Task {
            for list in listsToLoad {
                self.loadingListIds.insert(list.list_id)
            }

            await preloadPlacesForLists(listsToLoad)

            for list in listsToLoad {
                self.loadingListIds.remove(list.list_id)
            }
        }
    }

    // MARK: - List Popup

    func onListPopupDismissed() {
        shouldShowListPopup = false
        pendingListIndex = nil
    }
}
