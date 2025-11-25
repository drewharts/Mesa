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
    @Published var selectedUser: ProfileData?
    @Published var isUserDetailPresented = false
    
    // Lightweight objects for external user profile
    @Published var userFavorites: [FavoritePlace] = []
    @Published var userLists: [LightweightPlaceList] = []
    @Published var placeListPlaces: [String: [LightweightPlace]] = [:] // [listId: places]
    
    // Lazy loading properties
    private var loadedListIds: Set<String> = []
    private var loadingListIds: Set<String> = []
    @Published var isFollowing: Bool = false
    @Published var followers: Int = 0
    
    // Follow error handling
    @Published var showFollowError: Bool = false
    @Published var followErrorMessage: String = ""
    
    // Reviewed places loading state
    @Published var isLoadingReviewedPlaces: Bool = false
    private var hasAttemptedLoadReviewedPlaces: [String: Bool] = [:]
    
    // Pagination properties for user reviews
    @Published var isLoadingMoreReviews: Bool = false
    private var hasMoreReviews: [String: Bool] = [:] // userId -> hasMoreReviews
    private var currentReviewPage: [String: Int] = [:] // userId -> page number
    private let reviewsPerPage: Int = 8
    private var allReviewedPlaceIds: [String: [String]] = [:] // userId -> [placeIds]
    private var loadedReviewedPlaceIds: [String: [String]] = [:] // userId -> [loaded placeIds]
    
    private let placeService: PlaceService
    private let userService: UserService
    private let reviewService: ReviewService
    
    private let dataManager: DataManager
    private let detailPlaceViewModel: DetailPlaceViewModel
    
    init(
        dataManager: DataManager, 
        detailPlaceViewModel: DetailPlaceViewModel,
        placeService: PlaceService,
        userService: UserService,
        reviewService: ReviewService
    ) {
        self.dataManager = dataManager
        self.detailPlaceViewModel = detailPlaceViewModel
        self.placeService = placeService
        self.userService = userService
        self.reviewService = reviewService
    }
    
    func selectUser(_ user: ProfileData, currentUserId: String) {
        self.selectedUser = user
        self.isUserDetailPresented = true
        self.checkIfFollowing(currentUserId: currentUserId)
        self.fetchProfileFavorites(userId: user.id)
        self.fetchLists(userId: user.id)
        self.fetchFollowers(userId: user.id)
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
    
    func fetchFollowers(userId: String) {
        userService.getNumberFollowers(forUserId: userId) { (count, error) in
            if let error = error {
                print("Error fetching followers: \(error.localizedDescription)")
                return
            }
            self.followers = count
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
                        pageSize: 6
                    )
                } else {
                    // Fallback: fetch lists without proximity sorting
                    // For now, return empty - ideally we'd have a non-proximity version
                    lists = []
                }
                
                await MainActor.run {
                    self.userLists = lists
                }
                
                // Load places for each list (first 6 places per list)
                for list in lists.prefix(3) {
                    await loadPlacesForList(listId: list.list_id)
                }
                
            } catch {
                print("❌ [UserProfileViewModel] Error fetching lists: \(error)")
                await MainActor.run {
                    self.userLists = []
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
    
    /// Load more lists when user scrolls (lazy loading)
    func loadMoreListsIfNeeded() {
        // Find the next 3 lists that haven't been loaded yet
        let unloadedLists = userLists.filter { !loadedListIds.contains($0.list_id) && !loadingListIds.contains($0.list_id) }
        let nextThreeLists = Array(unloadedLists.prefix(3))
        
        guard !nextThreeLists.isEmpty else { return }
        
        Task {
            // Mark as loading
            await MainActor.run {
                for list in nextThreeLists {
                    self.loadingListIds.insert(list.list_id)
                }
            }
            
            // Load places for these lists
            for list in nextThreeLists {
                await loadPlacesForList(listId: list.list_id)
            }
            
            await MainActor.run {
                for list in nextThreeLists {
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
    
    func loadUserReviewedPlacesWithPagination() {
        guard let userId = selectedUser?.id else { return }
        
        // Reset pagination state for new user
        if hasAttemptedLoadReviewedPlaces[userId] != true {
            resetPaginationState()
            hasAttemptedLoadReviewedPlaces[userId] = true
        }
        
        Task {
            await loadUserReviewedPlacesPaginated(userId: userId)
        }
    }
    
    private func resetPaginationState() {
        currentReviewPage.removeAll()
        allReviewedPlaceIds.removeAll()
        loadedReviewedPlaceIds.removeAll()
        hasMoreReviews.removeAll()
        isLoadingMoreReviews = false
    }
    
    private func loadUserReviewedPlacesPaginated(userId: String) async {
        // If this is the first load, get all review place IDs
        if allReviewedPlaceIds[userId] == nil {
            await MainActor.run {
                isLoadingReviewedPlaces = true
            }
            
            do {
                let restaurantReviews: [RestaurantReview] = try await reviewService.fetchUserReviews(userId: userId)
                let genericReviews: [GenericReview] = try await reviewService.fetchUserGenericReviews(userId: userId)
                let allReviews: [ReviewProtocol] = restaurantReviews + genericReviews
                
                // Sort reviews by timestamp (most recent first) and get unique place IDs while preserving order
                let sortedReviews = allReviews.sorted { $0.timestamp > $1.timestamp }

                // Get unique place IDs while preserving the order of most recently reviewed places
                var seenPlaceIds = Set<String>()
                let uniquePlaceIds: [String] = sortedReviews.compactMap { review in
                    if seenPlaceIds.contains(review.placeId) {
                        return nil
                    }
                    seenPlaceIds.insert(review.placeId)
                    return review.placeId
                }

                await MainActor.run {
                    allReviewedPlaceIds[userId] = uniquePlaceIds
                    // Initialize hasMoreReviews for this user
                    hasMoreReviews[userId] = !allReviewedPlaceIds[userId]!.isEmpty
                }
            } catch {
                print("Error fetching user reviews for pagination: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingReviewedPlaces = false
                }
                return
            }
        }
        
        // If there are no reviews at all, ensure loading state is reset
        if allReviewedPlaceIds[userId]?.isEmpty == true {
            await MainActor.run {
                isLoadingReviewedPlaces = false
            }
            return
        }
        
        // Load the next batch of reviews
        await loadNextBatchOfReviews(userId: userId)
    }
    
    private func loadNextBatchOfReviews(userId: String) async {
        guard !isLoadingMoreReviews && hasMoreReviews[userId] != false else { 
            // Safety check: if we can't load more, ensure initial loading is complete
            await MainActor.run {
                isLoadingReviewedPlaces = false
            }
            return 
        }
        
        await MainActor.run {
            isLoadingMoreReviews = true
        }
        
        let startIndex = currentReviewPage[userId] ?? 0
        let endIndex = min(startIndex + reviewsPerPage, allReviewedPlaceIds[userId]?.count ?? 0)
        
        guard startIndex < (allReviewedPlaceIds[userId]?.count ?? 0) else {
            await MainActor.run {
                hasMoreReviews[userId] = false
                isLoadingMoreReviews = false
                isLoadingReviewedPlaces = false
            }
            return
        }
        
        let placeIdsToLoad = Array(allReviewedPlaceIds[userId]![startIndex..<endIndex])
        
        // Load places and their details
        var successfullyLoadedPlaceIds: [String] = []
        
        for placeId in placeIdsToLoad {
            // Add userId to placeSavers if not already present
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
            
            // Fetch and store the place if not already present
            if detailPlaceViewModel.places[placeId] == nil {
                // Retry logic for failed place loads
                var retryCount = 0
                let maxRetries = 2

                while retryCount <= maxRetries {
                    do {
                        let detailPlace = try await placeService.fetchPlace(withId: placeId)
                        await MainActor.run {
                            detailPlaceViewModel.places[placeId] = detailPlace
                            detailPlaceViewModel.fetchPlaceImage(for: placeId)
                            // Only add to successfully loaded places if we got the data
                            successfullyLoadedPlaceIds.append(placeId)
                        }
                        break // Success, exit retry loop
                    } catch {
                        retryCount += 1
                        if retryCount <= maxRetries {
                            print("⚠️ [UserProfileViewModel] Failed to load place \(placeId), retrying (\(retryCount)/\(maxRetries)): \(error.localizedDescription)")
                            try? await Task.sleep(nanoseconds: 500_000_000 * UInt64(retryCount)) // Exponential backoff
                        } else {
                            print("❌ [UserProfileViewModel] Failed to load place \(placeId) after \(maxRetries) retries: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                // Place already exists, add to successfully loaded
                successfullyLoadedPlaceIds.append(placeId)
            }
        }
        
        await MainActor.run {
            if loadedReviewedPlaceIds[userId] == nil {
                loadedReviewedPlaceIds[userId] = []
            }
            // Only add place IDs that aren't already in the list
            let newPlaceIds = successfullyLoadedPlaceIds.filter { placeId in
                !loadedReviewedPlaceIds[userId]!.contains(placeId)
            }
            loadedReviewedPlaceIds[userId]?.append(contentsOf: newPlaceIds)
            currentReviewPage[userId] = (currentReviewPage[userId] ?? 0) + 1
            hasMoreReviews[userId] = endIndex < (allReviewedPlaceIds[userId]?.count ?? 0)
            isLoadingMoreReviews = false
            isLoadingReviewedPlaces = false
        }
    }
    
    func loadMoreReviews() {
        guard let userId = selectedUser?.id else { return }
        Task {
            await loadNextBatchOfReviews(userId: userId)
        }
    }
    
    // Get places that this user has reviewed (with pagination)
    func getReviewedPlaces() -> [DetailPlace] {
        guard let userId = selectedUser?.id else { return [] }
        
        // Return only the loaded places for pagination
        return loadedReviewedPlaceIds[userId]?.compactMap { detailPlaceViewModel.places[$0] } ?? []
    }
    
    // Get all reviewed places (for backward compatibility)
    func getAllReviewedPlaces() -> [DetailPlace] {
        guard let userId = selectedUser?.id else { return [] }
        
        // Find all places where this user is in the placeSavers array
        let reviewedPlaceIds = detailPlaceViewModel.placeSavers.compactMap { (placeId, userIds) -> String? in
            return userIds.contains(userId) ? placeId : nil
        }
        
        // Get the actual DetailPlace objects for those IDs
        return reviewedPlaceIds.compactMap { detailPlaceViewModel.places[$0] }
    }
    
    // Get hasMoreReviews for a specific user
    func hasMoreReviews(for userId: String) -> Bool {
        return hasMoreReviews[userId] ?? true
    }
    
    // Check if we've attempted to load reviews for a specific user
    func hasAttemptedLoadReviews(for userId: String) -> Bool {
        return hasAttemptedLoadReviewedPlaces[userId] ?? false
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

