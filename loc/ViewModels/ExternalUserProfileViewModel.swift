//
//  ExternalUserProfileViewModel.swift
//  loc
//
//  Created for Instagram-style nested profile navigation.
//  Each profile in the navigation stack gets its own independent ViewModel instance.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for external user profiles that is instantiated per-view using @StateObject.
/// This enables Instagram-style nested navigation where each profile maintains its own state.
@MainActor
class ExternalUserProfileViewModel: ObservableObject {
    // MARK: - Core Identity (set at init, immutable)
    let userId: String
    @Published var user: ProfileData

    // MARK: - Child ViewModels for Lists
    let listsDataViewModel: ExternalListsDataViewModel
    let listsLoadingViewModel: ExternalListsLoadingViewModel

    // MARK: - Combine Subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Profile Data
    @Published var userFavorites: [FavoritePlace] = []
    @Published var lightweightReviewedPlaces: [LightweightPlace] = []

    // MARK: - Proxy Properties for Lists (delegate to child ViewModels)

    /// User's place lists (proxied from listsDataViewModel).
    var userLists: [LightweightPlaceList] {
        listsDataViewModel.userLists
    }

    /// Places in each list by list ID (proxied from listsDataViewModel).
    var placeListPlaces: [String: [LightweightPlace]] {
        listsDataViewModel.placeListPlaces
    }

    /// Whether there are more lists to load (proxied from listsDataViewModel).
    var hasMoreLists: Bool {
        listsDataViewModel.hasMoreLists
    }

    /// Loading more lists (proxied from listsLoadingViewModel).
    var isLoadingMoreLists: Bool {
        listsLoadingViewModel.isLoadingMoreLists
    }

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

    // MARK: - Deep Link List Popup State
    @Published var shouldShowListPopup = false
    @Published var pendingListIndex: Int?
    private var pendingListIdToOpen: String?

    // MARK: - List Search State
    @Published var isSearchingLists: Bool = false
    @Published var listSearchText: String = ""
    private var listSearchCancellable: AnyCancellable?

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

        // Initialize child ViewModels for lists
        let dataVM = ExternalListsDataViewModel()
        self.listsDataViewModel = dataVM
        self.listsLoadingViewModel = ExternalListsLoadingViewModel(
            userId: user.id,
            userService: self.userService,
            dataViewModel: dataVM
        )

        // Set up Combine subscriptions for change propagation
        setupListsViewModelObservers()

        // Set up debounced list search observer
        setupListSearchObserver()
    }

    // MARK: - Child ViewModel Change Propagation

    /// Subscribes to child ViewModels and forwards their changes to trigger parent updates.
    private func setupListsViewModelObservers() {
        listsDataViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        listsLoadingViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Dependency Injection

    /// Sets the location manager for proximity-based list sorting.
    func setLocationManager(_ locationManager: LocationManager) {
        listsLoadingViewModel.setLocationManager(locationManager)
    }

    // MARK: - Initial Data Loading

    /// Loads all initial data for the profile. Called once when view appears.
    func loadInitialData(currentUserId: String) async {
        // Run all initial fetches in parallel
        async let profileRefresh: () = refreshUserProfile()
        async let followingCheck: () = checkIfFollowing(currentUserId: currentUserId)
        async let favoritesLoad: () = fetchProfileFavorites()
        async let listsLoad: () = fetchLists()
        async let followersLoad: () = fetchFollowers()
        async let followingCountLoad: () = fetchFollowingCount()
        async let placesCountLoad: () = fetchTotalPlacesCount()

        _ = await (profileRefresh, followingCheck, favoritesLoad, listsLoad, followersLoad, followingCountLoad, placesCountLoad)
    }

    /// Refreshes the user profile data to ensure all fields (including social links) are current.
    private func refreshUserProfile() async {
        do {
            let refreshedProfile = try await userService.fetchUserById(userId: userId)
            self.user = refreshedProfile
        } catch {
            // Non-fatal: keep existing user data if refresh fails
            print("ExternalUserProfileViewModel Error refreshing profile: \(error)")
        }
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

    /// Delegates list fetching to child ViewModel.
    private func fetchLists() async {
        await listsLoadingViewModel.loadInitialLists()

        // Check for pending deep link list
        await checkAndShowPendingList(lists: listsDataViewModel.userLists)
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
                self.listsDataViewModel.insertListAtBeginning(list)

                // Now find the index and show popup
                if let index = self.listsDataViewModel.userLists.firstIndex(where: { $0.list_id == listId }) {
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

    /// Delegates list pagination to child ViewModel.
    func fetchMoreLists() {
        Task {
            await listsLoadingViewModel.loadMoreLists()
        }
    }

    /// Delegates place loading for a single list to child ViewModel.
    func loadPlacesForList(_ list: LightweightPlaceList) {
        Task {
            await listsLoadingViewModel.loadPlacesForList(list)
        }
    }

    /// Loads more places for a list with pagination via child ViewModel.
    func loadMorePlacesForList(_ list: LightweightPlaceList, page: Int, completion: @escaping ([LightweightPlace]) -> Void) {
        Task {
            let places = await listsLoadingViewModel.loadMorePlacesForList(listId: list.list_id, page: page)
            completion(places)
        }
    }

    // MARK: - List Search

    /// Sets up debounced observer for list search text changes.
    private func setupListSearchObserver() {
        listSearchCancellable = $listSearchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.performListSearch()
                }
            }
    }

    /// Performs server-side search across the user's lists by name.
    func performListSearch() async {
        let searchTerm = listSearchText.trimmingCharacters(in: .whitespaces)
        guard !searchTerm.isEmpty else { return }

        do {
            let searchResults = try await PlaceListService.shared.searchListsByName(
                userId: userId,
                searchTerm: searchTerm
            )

            listsDataViewModel.userLists = searchResults

            // Load places for search results in parallel
            await withTaskGroup(of: (String, [LightweightPlace]?).self) { group in
                for list in searchResults {
                    group.addTask {
                        do {
                            let places = try await self.userService.fetchPlacesForPlaceList(
                                listId: list.list_id,
                                page: 1,
                                pageSize: 6
                            )
                            return (list.list_id, places)
                        } catch {
                            return (list.list_id, nil)
                        }
                    }
                }

                for await (listId, places) in group {
                    if let places = places {
                        self.listsDataViewModel.setPlacesForList(listId: listId, places: places)
                    }
                }
            }
        } catch {
            print("ExternalUserProfileViewModel Error searching lists: \(error)")
        }
    }

    /// Reloads lists when exiting search mode, restoring proximity-sorted results.
    func reloadListsAfterSearch() async {
        await listsLoadingViewModel.loadInitialLists()
    }

    // MARK: - List Popup

    func onListPopupDismissed() {
        shouldShowListPopup = false
        pendingListIndex = nil
    }
}
