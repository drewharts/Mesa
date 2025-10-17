//  UserProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation
import UIKit
import SwiftUI
import MapboxSearch

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var selectedUser: ProfileData?
    @Published var isUserDetailPresented = false
    
    @Published var userFavorites: [DetailPlace] = []
    @Published var favoritePlaceImages: [String: UIImage] = [:]

    @Published var userLists: [PlaceList] = []
    @Published var placeListMapboxPlaces: [UUID: [DetailPlace]] = [:]
    @Published var placeImages: [String: UIImage] = [:]
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
        self.fetchFavoritePlaceImages()
    }
    
    func fetchAndSelectUser(userId: String, currentUserId: String) {
        userService.fetchUserById(userId: userId) { [weak self] result in
            switch result {
            case .success(let profileData):
                self?.selectUser(profileData, currentUserId: currentUserId)
            case .failure(let error):
                print("Error fetching user profile: \(error.localizedDescription)")
                // Optionally handle error - could show an alert or set an error state
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
            self.isFollowing = false
            return
        }
        userService.isFollowingUser(followerId: currentUserId, followingId: targetUserId) { [weak self] isFollowing in
            self?.isFollowing = isFollowing
        }
    }
    
    func toggleFollowUser(currentUserId: String) {
        guard let targetUserId = selectedUser?.id else { return }
        
        // Store original state for potential rollback
        let originalFollowingState = isFollowing
        let originalFollowersCount = followers
        
        if isFollowing {
            // Optimistic update: immediately change UI
            self.isFollowing = false
            self.followers = max(0, self.followers - 1)
            // Remove user from placeSavers and recalculate annotations
            self.removeUserFromPlaceSavers(userId: targetUserId)
            self.detailPlaceViewModel.calculateAnnotationPlaces()
            
            // Make the actual API call
            userService.unfollowUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if !success {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self.isFollowing = originalFollowingState
                        self.followers = originalFollowersCount
                        // Re-add user to placeSavers and recalculate annotations
                        self.addUserToPlaceSavers(userId: targetUserId)
                        self.detailPlaceViewModel.calculateAnnotationPlaces()
                        // Show error alert
                        self.showFollowError = true
                        self.followErrorMessage = "Failed to unfollow user. Please try again."
                    }
                }
            }
        } else {
            // Optimistic update: immediately change UI
            self.isFollowing = true
            self.followers += 1
            
            // Make the actual API call
            userService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    // Load new user's places and recalculate annotations on success
                    Task {
                        await self.dataManager.loadUserFavoritePlaces(userId: targetUserId, forUser: self.selectedUser)
                        await self.dataManager.loadUserPlaceLists(userId: targetUserId, forUser: self.selectedUser)
                        self.detailPlaceViewModel.calculateAnnotationPlaces()
                    }
                } else {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self.isFollowing = originalFollowingState
                        self.followers = originalFollowersCount
                        // Show error alert
                        self.showFollowError = true
                        self.followErrorMessage = "Failed to follow user. Please try again."
                    }
                }
            }
        }
    }
    
    func followUser(currentUserId: String, targetUserId: String) {
        userService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
            if let error = error {
                print("Error following user: \(error.localizedDescription)")
            } else if success {
                print("Successfully followed user \(targetUserId).")
            }
        }
    }
    
    private func fetchProfileFavorites(userId: String) {
        print("Fetching favorites for userId: \(userId)")
        placeService.fetchProfileFavorites(userId: userId) { [weak self] favorites, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching favorites: \(error)")
                self.userFavorites = []
            } else if favorites.isEmpty {
                print("No favorites found for userId: \(userId)")
                self.userFavorites = []
            } else {
                print("Fetched \(favorites.count) favorites for userId: \(userId)")
                self.userFavorites = favorites
            }
        }
    }
    
    func fetchFavoritePlaceImages() {
        print("Starting fetchFavoritePlaceImages for \(userFavorites.count) favorites")
        for place in userFavorites {
            fetchImage(for: place) { [weak self] placeId, image in
                guard let self = self else { return }
                if let image = image {
                    self.favoritePlaceImages[placeId] = image
                    // Explicitly trigger UI update
                    self.objectWillChange.send()
                    print("Updated image for place \(placeId) in favoritePlaceImages")
                }
            }
        }
    }
    
    private func fetchLists(userId: String) {
        // Use proximity-based sorting if location is available
        let userLocation = dataManager.currentUserLocation
        
        if let userLocation = userLocation {
            print("📍 [UserProfileViewModel] Loading place lists with proximity sorting")
            placeService.fetchListsByProximity(userId: userId, userLocation: userLocation) { lists in
                self.userLists = lists
                // Fetch places and images for each PlaceList
                for list in lists {
                    self.fetchFirestorePlaces(for: list.places) { places in
                        self.placeListMapboxPlaces[list.id] = places
                        // Fetch images for places in this list
                        for place in places {
                            self.fetchImage(for: place) { [weak self] placeId, image in
                                self?.placeImages[placeId] = image
                            }
                        }
                    }
                }
            }
        } else {
            print("📍 [UserProfileViewModel] Loading place lists with regular sorting (no location)")
            placeService.fetchLists(userId: userId) { lists in
                self.userLists = lists
                // Fetch places and images for each PlaceList
                for list in lists {
                    self.fetchFirestorePlaces(for: list.places) { places in
                        self.placeListMapboxPlaces[list.id] = places
                        // Fetch images for places in this list
                        for place in places {
                            self.fetchImage(for: place) { [weak self] placeId, image in
                                self?.placeImages[placeId] = image
                            }
                        }
                    }
                }
            }
        }
    }
    
    func fetchFirestorePlaces(for places: [Place], completion: @escaping ([DetailPlace]) -> Void) {
        var fetchedPlaces: [DetailPlace] = []
        let dispatchGroup = DispatchGroup()
        
        for place in places {
            dispatchGroup.enter()
            
            let documentId = place.id.uuidString
            
            placeService.fetchPlace(withId: documentId) { result in
                switch result {
                case .success(let detailPlace):
                    fetchedPlaces.append(detailPlace)
                case .failure(let error):
                    print("Error fetching place from Firestore: \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            DispatchQueue.main.async {
                completion(fetchedPlaces)
            }
        }
    }
    
    // Helper method to fetch images with completion handler
    private func fetchImage(for place: DetailPlace, completion: @escaping (String, UIImage?) -> Void) {
        let placeId = place.id.uuidString
        print("Starting image fetch for place: \(place.name) (\(placeId))")
        
        // Skip if image already exists in either dictionary
        if favoritePlaceImages[placeId] != nil || placeImages[placeId] != nil {
            print("Image already cached for place \(placeId)")
            completion(placeId, favoritePlaceImages[placeId] ?? placeImages[placeId])
            return
        }
        
        // First check if this place has TikTok videos from external places
        if let externalPlace = dataManager.getExternalPlace(for: placeId),
           let firstTikTokVideo = externalPlace.tiktokVideos.first,
           !firstTikTokVideo.thumbnailUrl.isEmpty {
            
            print("Found TikTok thumbnail for place \(placeId), loading...")
            self.loadTikTokThumbnailAsPlaceImage(placeId: placeId, thumbnailURL: firstTikTokVideo.thumbnailUrl, completion: completion)
            return
        }
        
        // Fetch reviews for this place
        reviewService.fetchReviews(placeId: placeId, latestOnly: false) { [weak self] (reviews: [ReviewProtocol]?, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(placeId, nil)
                }
                return
            }
            
            print("Found \(reviews?.count ?? 0) reviews for place \(placeId)")
            
            // Collect all image URLs from all reviews as strings (same as review images)
            var imageURLStrings: [String] = []
            for review in reviews ?? [] {
                imageURLStrings.append(contentsOf: review.images)
            }
            
            print("Found \(imageURLStrings.count) image URLs for place \(placeId)")
            
            if !imageURLStrings.isEmpty {
                // Use the same ImageService method that review images use for consistent processing
                ImageService.shared.fetchPhotosFromStorage(urls: imageURLStrings) { [weak self] images, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error fetching place image for \(placeId): \(error.localizedDescription)")
                            completion(placeId, nil)
                        } else if let images = images, !images.isEmpty {
                            // Use the first successfully loaded image as the place cover image
                            let image = images[0]
                            print("Successfully cached image for place \(placeId)")
                            self.placeImages[placeId] = image
                            completion(placeId, image)
                        } else {
                            print("No images returned for place \(placeId)")
                            completion(placeId, nil)
                        }
                    }
                }
            } else {
                print("No image URLs found for place \(placeId)")
                DispatchQueue.main.async {
                    completion(placeId, nil)
                }
            }
        }
    }
    
    /// Get TikTok videos for a specific place
    func getTikTokVideos(for placeId: String) -> [TikTokVideo] {
        if let externalPlace = dataManager.getExternalPlace(for: placeId) {
            return externalPlace.tiktokVideos.compactMap { convertExternalTikTokVideoToTikTokVideo($0) }
        }
        return []
    }
    
    /// Convert ExternalTikTokVideo to TikTokVideo
    private func convertExternalTikTokVideoToTikTokVideo(_ externalVideo: ExternalTikTokVideo) -> TikTokVideo? {
        let tikTokAuthor = TikTokAuthor(
            displayName: externalVideo.author.displayName,
            url: "", // Not available in external format
            username: externalVideo.author.username
        )
        
        return TikTokVideo(
            videoID: externalVideo.videoId,
            url: externalVideo.url,
            title: nil, // Not available in external format
            caption: nil, // Not available in external format
            embedHTML: externalVideo.embedHtml,
            thumbnailURL: externalVideo.thumbnailUrl,
            author: tikTokAuthor,
            hashtags: externalVideo.hashtags,
            createdAt: externalVideo.createdAt
        )
    }
    
    /// Get first TikTok thumbnail URL for a place
    func getFirstTikTokThumbnailURL(for placeId: String) -> String? {
        if let externalPlace = dataManager.getExternalPlace(for: placeId),
           let firstTikTokVideo = externalPlace.tiktokVideos.first,
           !firstTikTokVideo.thumbnailUrl.isEmpty {
            return firstTikTokVideo.thumbnailUrl
        }
        return nil
    }
    
    /// Load TikTok thumbnail as place image for external places
    public func loadTikTokThumbnailAsPlaceImage(placeId: String, thumbnailURL: String, completion: @escaping (String, UIImage?) -> Void) {
        guard let url = URL(string: thumbnailURL) else {
            print("❌ [UserProfileViewModel] Invalid thumbnail URL for place \(placeId): \(thumbnailURL)")
            DispatchQueue.main.async {
                completion(placeId, nil)
            }
            return
        }
        
        // Loading TikTok thumbnail for place
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [UserProfileViewModel] Error loading TikTok thumbnail for \(placeId): \(error.localizedDescription)")
                    completion(placeId, nil)
                } else if let data = data, let image = UIImage(data: data) {
                    // Successfully loaded TikTok thumbnail
                    // Store in both dictionaries to ensure consistency
                    self.placeImages[placeId] = image
                    completion(placeId, image)
                } else {
                    print("⚠️ [UserProfileViewModel] No image data returned for TikTok thumbnail \(placeId)")
                    completion(placeId, nil)
                }
            }
        }.resume()
    }
    
    func downloadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }
        return image
    }
    
    // Helper to remove a user from all placeSavers
    private func removeUserFromPlaceSavers(userId: String) {
        for (placeId, savers) in detailPlaceViewModel.placeSavers {
            detailPlaceViewModel.placeSavers[placeId] = savers.filter { $0 != userId }
            // Optionally, remove the place if no savers left:
            // if detailPlaceViewModel.placeSavers[placeId]?.isEmpty == true {
            //     detailPlaceViewModel.places.removeValue(forKey: placeId)
            // }
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
}
