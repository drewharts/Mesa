//  UserProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation
import UIKit
import SwiftUI

@MainActor
class UserProfileViewModel: ObservableObject {
    // MARK: - Profile Navigation State
    @Published var selectedUser: ProfileData?
    @Published var isUserDetailPresented = false
    
    // MARK: - External Profile Data
    @Published var userFavorites: [FavoritePlace] = []
    @Published var userLists: [LightweightPlaceList] = []
    @Published var placeListPlaces: [String: [LightweightPlace]] = [:] // [listId: places]
    
    // MARK: - Deep Link List Popup State (ViewModel owns presentation logic)
    @Published var shouldShowListPopup = false
    @Published var pendingListIndex: Int?
    private var pendingListIdToOpen: String?
    
    // MARK: - List Pagination State
    @Published var isLoadingMoreLists: Bool = false
    private var currentListPage: Int = 1
    private var hasMoreLists: Bool = true
    private let listsPerPage: Int = 6
    
    // MARK: - List Places Loading State
    private var loadedListIds: Set<String> = []
    private var loadingListIds: Set<String> = []
    
    // MARK: - Social State
    @Published var isFollowing: Bool = false
    @Published var followers: Int = 0
    @Published var totalPlacesCount: Int = 0  // Total unique places (saved + reviewed + created)
    
    // Follow error handling
    @Published var showFollowError: Bool = false
    @Published var followErrorMessage: String = ""
    
    // MARK: - Reviewed Places State (LightweightPlace for consistent image loading)
    @Published var lightweightReviewedPlaces: [LightweightPlace] = []
    @Published var isLoadingReviewedPlaces: Bool = false
    @Published var isLoadingMoreReviews: Bool = false
    @Published var hasMoreReviews: Bool = true  // @Published to trigger SwiftUI updates
    @Published var totalReviewedPlacesCount: Int = 0 // Total count of reviewed places
    private var hasAttemptedLoadReviewedPlaces: [String: Bool] = [:]
    private var hasMoreReviewsForUser: [String: Bool] = [:] // userId -> hasMoreReviews (for reference)
    private let reviewsPerPage: Int = 8
    
    private let placeService: PlaceService
    private let userService: UserService
    private let postService: PostService
    private let userSession: UserSession
    
    private let dataManager: DataManager
    private let detailPlaceViewModel: DetailPlaceViewModel
    
    private var notificationObserver: NSObjectProtocol?
    
    init(
        dataManager: DataManager, 
        detailPlaceViewModel: DetailPlaceViewModel,
        placeService: PlaceService,
        userService: UserService,
        postService: PostService,
        userSession: UserSession
    ) {
        self.dataManager = dataManager
        self.detailPlaceViewModel = detailPlaceViewModel
        self.placeService = placeService
        self.userService = userService
        self.postService = postService
        self.userSession = userSession
        
        setupNotificationObserver()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Sets up observer for follow notification navigation
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToUserProfileFromNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userId = notification.userInfo?["userId"] as? String,
                  let currentUserId = self.userSession.currentUserId else {
                return
            }
            self.fetchAndSelectUser(userId: userId, currentUserId: currentUserId)
        }
    }
    
    func selectUser(_ user: ProfileData, currentUserId: String) {
        self.selectedUser = user
        self.isUserDetailPresented = true
        
        // Reset ALL state for new user (Single Responsibility: one place for all resets)
        resetListPaginationState()
        resetReviewedPlacesLoadingState()
        totalPlacesCount = 0
        
        self.checkIfFollowing(currentUserId: currentUserId)
        self.fetchProfileFavorites(userId: user.id)
        self.fetchLists(userId: user.id)
        self.fetchFollowers(userId: user.id)
        self.fetchTotalPlacesCount(userId: user.id)
    }
    
    /// Resets all list-related state when switching to a new user profile
    private func resetListPaginationState() {
        userLists = []
        placeListPlaces = [:]
        loadedListIds = []
        loadingListIds = []
        currentListPage = 1
        hasMoreLists = true
        isLoadingMoreLists = false
    }
    
    func fetchAndSelectUser(userId: String, currentUserId: String) {
        userService.fetchUserById(userId: userId) { [weak self] result in
            switch result {
            case .success(let profileData):
                self?.selectUser(profileData, currentUserId: currentUserId)
            case .failure(let error):
                print("Error fetching user profile: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Deep Link Navigation
    
    /// Navigates to a user's profile and queues a specific list to auto-open
    /// Called by DeepLinkManager when handling list deep links
    func navigateToUserWithList(userId: String, listId: String, currentUserId: String) {
        // Store the pending list ID - will be matched when lists load
        self.pendingListIdToOpen = listId
        self.shouldShowListPopup = false
        self.pendingListIndex = nil
        
        userService.fetchUserById(userId: userId) { [weak self] result in
            switch result {
            case .success(let profileData):
                self?.selectUser(profileData, currentUserId: currentUserId)
            case .failure(let error):
                print("Error fetching user profile: \(error.localizedDescription)")
                self?.clearPendingListState()
            }
        }
    }
    
    /// Called by View when list popup is dismissed
    func onListPopupDismissed() {
        shouldShowListPopup = false
        pendingListIndex = nil
    }
    
    /// Clears all pending list state
    private func clearPendingListState() {
        pendingListIdToOpen = nil
        pendingListIndex = nil
        shouldShowListPopup = false
    }
    
    func fetchFollowers(userId: String) {
        userService.getNumberFollowers(forUserId: userId) { (count, error) in
            if let error = error {
                print("Error fetching followers: \(error.localizedDescription)")
                return
            }
            self.followers = count
        }
    }
    
    func fetchTotalPlacesCount(userId: String) {
        Task {
            do {
                let count = try await userService.getTotalPlacesCount(forUserId: userId)
                await MainActor.run {
                    self.totalPlacesCount = count
                }
            } catch {
                print("❌ [UserProfileVM] Error fetching total places count: \(error)")
            }
        }
    }
    
    func checkIfFollowing(currentUserId: String) {
        guard let targetUserId = selectedUser?.id, !targetUserId.isEmpty else {
            DispatchQueue.main.async {
                self.isFollowing = false
            }
            return
        }
        userService.isFollowingUser(followerId: currentUserId, followingId: targetUserId) { [weak self] isFollowing in
            DispatchQueue.main.async {
                self?.isFollowing = isFollowing
            }
        }
    }
    
    func toggleFollowUser(currentUserId: String, completion: @escaping (Bool, Bool) -> Void) {
        guard let targetUserId = selectedUser?.id else { 
            completion(false, isFollowing)
            return 
        }
        
        // Store original state for potential rollback
        let originalFollowingState = isFollowing
        let originalFollowersCount = followers
        
        if isFollowing {
            // Optimistic update with smooth animation
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isFollowing = false
                self.followers = max(0, self.followers - 1)
            }
            // Remove user from placeSavers and recalculate annotations
            self.removeUserFromPlaceSavers(userId: targetUserId)
            self.detailPlaceViewModel.calculateAnnotationPlaces()
            
            // Make the actual API call
            userService.unfollowUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if !success {
                    // Revert on failure with animation
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isFollowing = originalFollowingState
                        self.followers = originalFollowersCount
                        // Show error alert
                        self.showFollowError = true
                        self.followErrorMessage = "Failed to unfollow user. Please try again."
                    }
                    // Re-add user to placeSavers and recalculate annotations
                    self.addUserToPlaceSavers(userId: targetUserId)
                    self.detailPlaceViewModel.calculateAnnotationPlaces()
                    completion(false, originalFollowingState)
                } else {
                    completion(true, false)
                }
            }
        } else {
            // Optimistic update with smooth animation
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isFollowing = true
                self.followers += 1
            }
            
            // Make the actual API call
            userService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    // Load new user's places and recalculate annotations on success
                    Task {
                        await self.dataManager.loadUserFavoritePlaces(userId: targetUserId, forUser: self.selectedUser)
                        await self.dataManager.loadUserPlaceLists(userId: targetUserId, forUser: self.selectedUser)
                        self.detailPlaceViewModel.calculateAnnotationPlaces()
                    }
                    completion(true, true)
                } else {
                    // Revert on failure with animation
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isFollowing = originalFollowingState
                        self.followers = originalFollowersCount
                        // Show error alert
                        self.showFollowError = true
                        self.followErrorMessage = "Failed to follow user. Please try again."
                    }
                    completion(false, originalFollowingState)
                }
            }
        }
    }
    
    func followUser(currentUserId: String, targetUserId: String) {
        userService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
            if let error = error {
                print("Error following user: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchProfileFavorites(userId: String) {
        Task {
            do {
                let favorites = try await userService.fetchUserFavorites(userId: userId)
                await MainActor.run {
                    self.userFavorites = favorites
                }
            } catch {
                print("❌ [UserProfileViewModel] Error fetching favorites: \(error)")
                await MainActor.run {
                    self.userFavorites = []
                }
            }
        }
    }
    
    private func fetchLists(userId: String) {
        // Use proximity-based sorting if location is available
        let userLocation = dataManager.currentUserLocation
        
        Task {
            do {
                let lists: [LightweightPlaceList]
                
                if let userLocation = userLocation {
                    lists = try await userService.fetchPlaceListsByProximity(
                        userId: userId,
                        userLatitude: userLocation.latitude,
                        userLongitude: userLocation.longitude,
                        page: 1,
                        pageSize: listsPerPage
                    )
                } else {
                    // Fallback: fetch lists without proximity sorting
                    // For now, return empty - ideally we'd have a non-proximity version
                    lists = []
                }
                
                await MainActor.run {
                    self.userLists = lists
                    self.currentListPage = 1
                    self.hasMoreLists = lists.count >= self.listsPerPage
                    self.checkAndShowPendingList(lists: lists)
                }
                
                // Preload places for first few visible lists
                await preloadPlacesForLists(Array(lists.prefix(3)))
                
            } catch {
                print("❌ [UserProfileViewModel] Error fetching lists: \(error)")
                await MainActor.run {
                    self.userLists = []
                    self.hasMoreLists = false
                    self.clearPendingListState()
                }
            }
        }
    }
    
    // MARK: - List Pagination
    
    /// Fetches the next page of lists from the backend
    /// Called by View when user scrolls near the end of the list
    func fetchMoreLists() {
        guard canFetchMoreLists else { return }
        guard let userId = selectedUser?.id else { return }
        
        isLoadingMoreLists = true
        let nextPage = currentListPage + 1
        let userLocation = dataManager.currentUserLocation
        
        Task {
            do {
                guard let userLocation = userLocation else {
                    await MainActor.run { self.isLoadingMoreLists = false }
                    return
                }
                
                let newLists = try await userService.fetchPlaceListsByProximity(
                    userId: userId,
                    userLatitude: userLocation.latitude,
                    userLongitude: userLocation.longitude,
                    page: nextPage,
                    pageSize: listsPerPage
                )
                
                await MainActor.run {
                    self.userLists.append(contentsOf: newLists)
                    self.currentListPage = nextPage
                    self.hasMoreLists = newLists.count >= self.listsPerPage
                    self.isLoadingMoreLists = false
                }
                
                // Preload places for newly fetched lists
                await preloadPlacesForLists(Array(newLists.prefix(3)))
                
            } catch {
                print("❌ [UserProfileViewModel] Error fetching more lists: \(error)")
                await MainActor.run {
                    self.isLoadingMoreLists = false
                }
            }
        }
    }
    
    /// Whether more lists can be fetched (not loading and more available)
    private var canFetchMoreLists: Bool {
        return hasMoreLists && !isLoadingMoreLists
    }
    
    /// Preloads places for a batch of lists
    private func preloadPlacesForLists(_ lists: [LightweightPlaceList]) async {
        for list in lists {
            await loadPlacesForList(listId: list.list_id)
        }
    }
    
    /// Checks if there's a pending list to open and triggers popup if found
    private func checkAndShowPendingList(lists: [LightweightPlaceList]) {
        guard let pendingListId = pendingListIdToOpen else { return }
        
        if let index = lists.firstIndex(where: { $0.list_id == pendingListId }) {
            // Found in current page - show popup
            showListPopupAtIndex(index, listId: pendingListId)
        } else {
            // List not in first page - fetch it specifically (for deep links)
            print("📋 [UserProfileViewModel] List \(pendingListId) not in first page, fetching directly...")
            Task {
                await fetchAndShowSpecificList(listId: pendingListId)
            }
        }
    }
    
    /// Fetches a specific list by ID and shows it (for deep links when list isn't in first page)
    private func fetchAndShowSpecificList(listId: String) async {
        do {
            guard let list = try await userService.fetchPlaceListById(listId: listId) else {
                print("❌ [UserProfileViewModel] Could not find list with ID: \(listId)")
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
                    self.showListPopupAtIndex(index, listId: listId)
                } else {
                    self.clearPendingListState()
                }
            }
        } catch {
            print("❌ [UserProfileViewModel] Error fetching specific list: \(error)")
            await MainActor.run { self.clearPendingListState() }
        }
    }
    
    /// Shows the list popup at a specific index after loading its places
    private func showListPopupAtIndex(_ index: Int, listId: String) {
        Task {
            await loadPlacesForList(listId: listId)
            
            await MainActor.run {
                self.pendingListIndex = index
                // Small delay to allow profile view to settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.shouldShowListPopup = true
                    self.pendingListIdToOpen = nil
                }
            }
        }
    }
    
    /// Load places for a specific list
    private func loadPlacesForList(listId: String) async {
        guard placeListPlaces[listId] == nil else { return }
        
        do {
            let places = try await userService.fetchPlacesForPlaceList(
                listId: listId,
                page: 1,
                pageSize: 6
            )
            
            await MainActor.run {
                self.placeListPlaces[listId] = places
                self.loadedListIds.insert(listId)
            }
        } catch {
            print("❌ [UserProfileViewModel] Error loading places for list \(listId): \(error)")
        }
    }
    
    /// Load places for a specific list (public version that can be called from views)
    func loadPlacesForList(_ list: LightweightPlaceList) {
        Task {
            await loadPlacesForList(listId: list.list_id)
        }
    }
    
    /// Load more places for a specific list (pagination)
    /// Used by ExternalUserListContentView for infinite scroll
    func loadMorePlacesForList(_ list: LightweightPlaceList, page: Int, completion: @escaping ([LightweightPlace]) -> Void) {
        Task {
            do {
                let morePlaces = try await userService.fetchPlacesForPlaceList(
                    listId: list.list_id,
                    page: page,
                    pageSize: 6
                )
                
                await MainActor.run {
                    // Append new places to existing ones
                    var existingPlaces = self.placeListPlaces[list.list_id] ?? []
                    
                    // Deduplicate
                    let existingIds = Set(existingPlaces.map { $0.id })
                    let newUniquePlaces = morePlaces.filter { !existingIds.contains($0.id) }
                    
                    existingPlaces.append(contentsOf: newUniquePlaces)
                    self.placeListPlaces[list.list_id] = existingPlaces
                    
                    completion(morePlaces)
                }
            } catch {
                print("❌ [UserProfileViewModel] Error loading more places for list \(list.list_id): \(error)")
                await MainActor.run {
                    completion([])
                }
            }
        }
    }
    
    /// Load more lists when user scrolls (lazy loading)
    /// Preloads places for lists that are becoming visible but haven't loaded their places yet
    /// This is called as user scrolls to lazy-load place data for each list
    func preloadPlacesForVisibleLists() {
        let unloadedLists = userLists.filter { 
            !loadedListIds.contains($0.list_id) && !loadingListIds.contains($0.list_id) 
        }
        let listsToLoad = Array(unloadedLists.prefix(3))
        
        guard !listsToLoad.isEmpty else { return }
        
        Task {
            await MainActor.run {
                for list in listsToLoad {
                    self.loadingListIds.insert(list.list_id)
                }
            }
            
            await preloadPlacesForLists(listsToLoad)
            
            await MainActor.run {
                for list in listsToLoad {
                    self.loadingListIds.remove(list.list_id)
                }
            }
        }
    }
    
    // Helper to remove a user from all placeSavers
    private func removeUserFromPlaceSavers(userId: String) {
        for (placeId, savers) in detailPlaceViewModel.placeSavers {
            detailPlaceViewModel.placeSavers[placeId] = savers.filter { $0 != userId }
        }
    }
    
    // Helper to add a user back to all placeSavers (for rollback)
    private func addUserToPlaceSavers(userId: String) {
        // This method is used for rollback when unfollow fails
        // We need to reload the user's places to restore them to placeSavers
        guard let selectedUser = selectedUser else { return }
        
        Task {
            await dataManager.loadUserFavoritePlaces(userId: userId, forUser: selectedUser)
            await dataManager.loadUserPlaceLists(userId: userId, forUser: selectedUser)
            detailPlaceViewModel.calculateAnnotationPlaces()
        }
    }
    
    // MARK: - Reviewed Places Loading
    
    func loadUserReviewedPlacesIfNeeded() {
        guard let userId = selectedUser?.id else { return }
        
        // Only load if we haven't attempted to load for this user yet
        if hasAttemptedLoadReviewedPlaces[userId] != true {
            isLoadingReviewedPlaces = true
            hasAttemptedLoadReviewedPlaces[userId] = true
            
            Task {
                await dataManager.loadUserReviewedPlaces(userId: userId)
                
                // Update loading state on main thread
                await MainActor.run {
                    isLoadingReviewedPlaces = false
                }
            }
        }
    }
    
    func resetReviewedPlacesLoadingState() {
        isLoadingReviewedPlaces = false
        hasAttemptedLoadReviewedPlaces.removeAll()
        resetPaginationState()
    }
    
    // MARK: - Pagination for User Reviews
    
    func loadUserReviewedPlacesWithPagination() async {
        guard let userId = selectedUser?.id else { return }
        
        // Reset pagination state for new user
        if hasAttemptedLoadReviewedPlaces[userId] != true {
            resetPaginationState()
            hasAttemptedLoadReviewedPlaces[userId] = true
        }
        
        await loadUserReviewedPlacesPaginated(userId: userId)
    }
    
    private func resetPaginationState() {
        lightweightReviewedPlaces = []
        hasMoreReviews = true
        totalReviewedPlacesCount = 0
        hasMoreReviewsForUser.removeAll()
        isLoadingMoreReviews = false
    }
    
    /// Load initial reviewed places using server-side pagination (LightweightPlace)
    /// Uses get_user_reviewed_places SQL function which includes latest_review_photo
    /// Note: Class is @MainActor so no need for MainActor.run wrappers
    private func loadUserReviewedPlacesPaginated(userId: String) async {
        isLoadingReviewedPlaces = true
        
        defer {
            isLoadingReviewedPlaces = false
        }
        
        do {
            // Fetch first page using server-side pagination (includes latest_review_photo!)
            // Also fetch total count in parallel
            async let placesTask = userService.fetchUserReviewedPlaces(userId: userId, limit: reviewsPerPage, offset: 0)
            async let countTask = SupabaseUserService.shared.getNumberReviewedPlaces(forUserId: userId)
            
            let (places, totalCount) = try await (placesTask, countTask)
            
            lightweightReviewedPlaces = places
            totalReviewedPlacesCount = totalCount
            hasMoreReviews = !places.isEmpty && places.count >= reviewsPerPage
            hasMoreReviewsForUser[userId] = hasMoreReviews
            
            print("✅ [UserProfileVM] Loaded \(places.count) reviewed places (total: \(totalCount)) for user \(userId)")
            
            // Prefetch TikTok metadata for places with TikTok URLs
            let tiktokUrls = places.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                }
            }
        } catch {
            print("❌ [UserProfileVM] Error loading reviewed places: \(error.localizedDescription)")
            hasMoreReviews = false
            hasMoreReviewsForUser[userId] = false
        }
    }
    
    /// Load more reviewed places (pagination)
    /// Note: Class is @MainActor so no need for MainActor.run wrappers
    private func loadNextBatchOfReviews(userId: String) async {
        guard !isLoadingMoreReviews, hasMoreReviews else { return }
        
        isLoadingMoreReviews = true
        
        defer {
            isLoadingMoreReviews = false
        }
        
        let offset = lightweightReviewedPlaces.count
        
        do {
            let places = try await userService.fetchUserReviewedPlaces(userId: userId, limit: reviewsPerPage, offset: offset)
            
            // Deduplicate to prevent SwiftUI rendering issues
            let existingIds = Set(lightweightReviewedPlaces.map { $0.id })
            let newUniquePlaces = places.filter { !existingIds.contains($0.id) }
            lightweightReviewedPlaces.append(contentsOf: newUniquePlaces)
            hasMoreReviews = !places.isEmpty && places.count >= reviewsPerPage
            hasMoreReviewsForUser[userId] = hasMoreReviews
            
            print("✅ [UserProfileVM] Loaded \(places.count) more reviewed places (total: \(lightweightReviewedPlaces.count))")
            
            // Prefetch TikTok metadata for new places
            let tiktokUrls = places.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                }
            }
        } catch {
            print("❌ [UserProfileVM] Error loading more reviewed places: \(error.localizedDescription)")
            hasMoreReviews = false
            hasMoreReviewsForUser[userId] = false
        }
    }
    
    func loadMoreReviews() async {
        guard let userId = selectedUser?.id else { return }
        await loadNextBatchOfReviews(userId: userId)
    }
    
    /// Get reviewed places as LightweightPlace (includes latest_review_photo for consistent image loading)
    func getReviewedPlaces() -> [LightweightPlace] {
        return lightweightReviewedPlaces
    }
    
    /// Get hasMoreReviews for a specific user
    func hasMoreReviews(for userId: String) -> Bool {
        return hasMoreReviewsForUser[userId] ?? true
    }
    
    /// Check if we've attempted to load reviews for a specific user
    func hasAttemptedLoadReviews(for userId: String) -> Bool {
        return hasAttemptedLoadReviewedPlaces[userId] ?? false
    }
    
    // MARK: - Logout Cleanup
    
    /// Clears all user-related cached data - MUST be called on logout to prevent data leakage
    /// Single Responsibility: Only clears this ViewModel's cached state
    func clearAllUserData() {
        print("🗑️ [UserProfileViewModel] Clearing all user data for security")
        
        // Clear profile navigation state
        selectedUser = nil
        isUserDetailPresented = false
        
        // Clear external profile data
        userFavorites.removeAll()
        userLists.removeAll()
        placeListPlaces.removeAll()
        
        // Clear reviewed places data
        lightweightReviewedPlaces.removeAll()
        totalReviewedPlacesCount = 0
        hasAttemptedLoadReviewedPlaces.removeAll()
        hasMoreReviewsForUser.removeAll()
        
        // Clear social state
        isFollowing = false
        followers = 0
        totalPlacesCount = 0
        
        // Reset pagination state
        currentListPage = 1
        hasMoreLists = true
        loadedListIds.removeAll()
        loadingListIds.removeAll()
        
        // Reset loading states
        isLoadingReviewedPlaces = false
        isLoadingMoreReviews = false
        hasMoreReviews = true
        isLoadingMoreLists = false
        
        // Clear popup state
        shouldShowListPopup = false
        pendingListIndex = nil
        pendingListIdToOpen = nil
        
        // Clear error state
        showFollowError = false
        followErrorMessage = ""
        
        print("✅ [UserProfileViewModel] All user data cleared")
    }
    
    // MARK: - Navigation
    
    /// Centralized navigation method for all external profile places (favorites, lists, reviews)
    /// Navigates back to the map, selects the place, and dismisses the user profile sheet
    func navigateToPlaceFromProfile(_ place: DetailPlace, selectedPlaceVM: SelectedPlaceViewModel) {
        selectedPlaceVM.navigateToMapAndSelectPlace(place) { [weak self] in
            self?.isUserDetailPresented = false
        }
    }
}

