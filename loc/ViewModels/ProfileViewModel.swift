//  ProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import Combine
import Foundation
import UIKit
import CoreLocation


// MARK: - List Place Pagination Model
struct ListPlacePagination {
    var allPlaceIds: [String] = []
    var loadedPlaceIds: [String] = []
    var currentPage: Int = 0
    var placesPerPage: Int = 5
    var isLoadingMore: Bool = false
    var hasMorePlaces: Bool = true
    
    var displayedPlaceIds: [String] {
        return loadedPlaceIds
    }
    
    var totalPlaces: Int {
        return allPlaceIds.count
    }
    
    var loadedCount: Int {
        return loadedPlaceIds.count
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: ProfileData? 
    @Published var userPicture: UIImage?
    @Published var userLists: [PlaceList] = []
    @Published var userListsPlaces: [String: [String]] = [:] // [listId: [placeId]]
    @Published var placeListCounts: [UUID: Int] = [:]
    @Published var userFavorites: [String] = [] // Legacy - full place IDs
    @Published var lightweightFavorites: [FavoritePlace] = [] // New - lightweight data for display
    @Published var lightweightPlaceLists: [LightweightPlaceList] = [] // New - lightweight place lists by proximity
    @Published var lightweightPlaceListPlaces: [String: [LightweightPlace]] = [:] // [listId: places]
    @Published var lightweightPlaceListCounts: [String: Int] = [:] // [listId: placeCount]
    @Published var lightweightMyPlaces: [LightweightPlace] = [] // Lightweight my places for tiles
    @Published var totalMyPlacesCount: Int = 0 // Total My Places count from database (not just loaded count)
    @Published var isLoadingMoreMyPlaces: Bool = false
    @Published var hasMoreMyPlaces: Bool = true
    @Published var lightweightExternalPlaces: [LightweightPlace] = [] // Lightweight external/TikTok places for tiles
    @Published var totalExternalPlacesCount: Int = 0 // Total TikTok count from database (not just loaded count)
    @Published var isLoadingMoreExternalPlaces: Bool = false
    @Published var hasMoreExternalPlaces: Bool = true
    @Published var isLoadingMorePlaceLists: Bool = false
    @Published var hasMorePlaceLists: Bool = true
    var placeListsCurrentPage: Int = 1
    
    // MARK: - Initial List Loading State
    /// True while initial list fetch (owned + shared) is in progress
    @Published var isLoadingInitialLists: Bool = false
    
    // MARK: - List Filter State
    @Published var showOnlySharedLists: Bool = false
    
    /// Returns filtered lists based on current filter state
    var filteredPlaceLists: [LightweightPlaceList] {
        if showOnlySharedLists {
            return lightweightPlaceLists.filter { $0.isCollaborative }
        }
        return lightweightPlaceLists
    }
    
    /// Count of collaborative lists (shared with you OR you shared with others)
    var collaborativeListCount: Int {
        lightweightPlaceLists.filter { $0.isCollaborative }.count
    }
    
    /// Whether there are any collaborative lists to filter
    var hasSharedLists: Bool {
        collaborativeListCount > 0
    }
    
    /// Whether the Shared filter button should be interactive
    /// Disabled while initial load is in progress to prevent confusing empty states
    var canInteractWithSharedFilter: Bool {
        !isLoadingInitialLists
    }
    
    // Save-to-list sheet pagination (separate from profile view pagination)
    @Published var userFollowing: [ProfileData] = []
    @Published var userFollowers: [ProfileData] = []
    @Published var myPlaces: [String] = [] // Legacy - keep for compatibility
    @Published var userExternalPlaces: [String: ExternalPlace] = [:] // PlaceId -> ExternalPlace
    @Published var recentlyCreatedListId: UUID?
    private var listCreationTime: Date?
    
    private let userService: UserService
    private let imageService: ImageService
    private let placeService: PlaceService
    private let postService: PostService
     internal let detailPlaceViewModel: DetailPlaceViewModel
     private let userSession: UserSession
    private var deepLinkManager: DeepLinkManager?
    private var deepLinkViewModel: DeepLinkViewModel?
    var userProfileViewModel: UserProfileViewModel?
    weak var mapViewModel: MapViewModel?  // For updating friends' places in viewport

     @Published var showMaxFavoritesAlert: Bool = false
     @Published var isLoading: Bool = true
     @Published var isUploadingProfilePhoto: Bool = false
     private var loadingTasks: Int = 0
     @Published var followersCount: Int = 0
     @Published var followingCount: Int = 0
     @Published var totalListCount: Int = 0
     @Published var totalUniquePlacesCount: Int = 0  // Total unique places (saved + reviewed + created)
     
     // Follow error handling
     @Published var showFollowError: Bool = false
     @Published var followErrorMessage: String = ""
    
    // Separate loading states for counts
    @Published var isFollowersLoading: Bool = true
    @Published var isFollowingLoading: Bool = true
    @Published var isMyPlacesLoading: Bool = true
    // Popup list loading states
    @Published var isFollowersListLoading: Bool = false
    @Published var isFollowingListLoading: Bool = false
    @Published var hasMoreFollowers: Bool = true
    @Published var hasMoreFollowing: Bool = true
    
    // TikTok processing state
    @Published var isProcessingTikTok: Bool = false
    @Published var isWaitingForPlaceDetail: Bool = false
    @Published var tikTokImportError: String? = nil
    @Published var importedPlaces: [DetailPlace] = []
    @Published var isShowingPlaceSelection: Bool = false
    @Published var isShowingNoPlacesFound: Bool = false
    @Published var noPlacesFoundTikTokUrl: String = ""
    private var currentProcessingTikTokUrl: String? = nil // Store URL during processing
    
    // MARK: - Account Management State
    @Published var showDeleteAccountWarning: Bool = false      // First warning
    @Published var showDeleteAccountConfirmation: Bool = false // Final confirmation
    @Published var isDeletingAccount: Bool = false
    @Published var deleteAccountError: String?
    
    // Lazy loading state for lists
    @Published var loadedListIds: Set<UUID> = []
    @Published var loadingListIds: Set<UUID> = []
    
    // Pagination state for places within each list
    @Published var listPlacePagination: [String: ListPlacePagination] = [:] // [listId: pagination state]
    
    // Performance optimization: image preloading cache
    @Published var preloadedImages: [String: Bool] = [:] // [imageURL: isPreloaded]

    // Add deduplication mechanism for TikTok URLs
    private var recentlyProcessedURLs: Set<String> = []

    // Concurrency control for list loading
    private let maxConcurrentListLoads = 2
    private var activeListLoadTasks: [UUID: Task<Void, Never>] = [:]
    
    // Pagination for reviewed places (server-side pagination like TikToks)
    @Published var isLoadingReviewedPlaces: Bool = false
    @Published var isLoadingMoreReviews: Bool = false
    @Published var hasMoreReviews: Bool = true
    @Published var lightweightReviewedPlaces: [LightweightPlace] = [] // Lightweight reviewed places for tiles
    @Published var totalReviewedPlacesCount: Int = 0 // Total reviewed places count from database (not just loaded count)
    private var hasAttemptedInitialReviewsLoad: Bool = false // Prevents infinite reload when user has no reviews
    private let reviewsPerPage: Int = 8
    
    // Pagination for TikTok places
    @Published var isLoadingTikTokPlaces: Bool = false
    
    // Place notes
    @Published var placeNotes: [String: PlaceNote] = [:] // [placeId: PlaceNote]
    
    // TikTok place flags
    @Published var tikTokPlaceFlags: [String: TikTokPlaceFlag] = [:] // [placeId: TikTokPlaceFlag]
    @Published var isLoadingMoreTikTokPlaces: Bool = false
    private var _hasMoreTikTokPlaces: Bool = true
    private var currentTikTokPage: Int = 0
    private let tikTokPlacesPerPage: Int = 8
    var allTikTokPlaceIds: [String] = []
    private var loadedTikTokPlaceIds: [String] = []
    
    // Location manager for distance calculations
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    init(userSession: UserSession, userService: UserService, detailPlaceViewModel: DetailPlaceViewModel, imageService: ImageService, placeService: PlaceService, postService: PostService, locationManager: LocationManager, deepLinkManager: DeepLinkManager? = nil, deepLinkViewModel: DeepLinkViewModel? = nil, userProfileViewModel: UserProfileViewModel? = nil) {
         self.userService = userService
         self.detailPlaceViewModel = detailPlaceViewModel
        self.userSession = userSession
        self.imageService = imageService
        self.placeService = placeService
        self.postService = postService
        self.locationManager = locationManager
        self.deepLinkManager = deepLinkManager
        self.deepLinkViewModel = deepLinkViewModel
        self.userProfileViewModel = userProfileViewModel
        
        // Observe location changes using Combine
        setupLocationObserver()
        
        // Observe TikTok multiple places notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TikTokMultiplePlacesFound"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let places = notification.userInfo?["places"] as? [DetailPlace],
               let tikTokUrl = notification.userInfo?["tikTokUrl"] as? String {
                Task { @MainActor in
                    self?.handleMultiplePlacesNotification(places: places, tikTokUrl: tikTokUrl)
                }
            } else if let places = notification.userInfo?["places"] as? [DetailPlace] {
                Task { @MainActor in
                    self?.handleMultiplePlaces(places)
                }
            }
        }
     }
    
    private func setupLocationObserver() {
        // Sort immediately when location becomes available (no need to wait for places to load)
        locationManager.$currentLocation
            .dropFirst() // Skip the initial nil value
            .sink { [weak self] location in
                if location != nil && !(self?.hasPerformedInitialSort ?? false) {
                    Task { @MainActor in
                        self?.sortListsByDistance()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
     func changeProfilePhoto(_ newImage: UIImage) async {
        // Set loading state and update UI immediately on main thread
        await MainActor.run {
            self.isUploadingProfilePhoto = true
            // Update UI immediately to show the new image for instant feedback
            self.userPicture = cropToSquare(newImage)
        }
        
        guard let userId = user?.id else { 
            print("❌ [ProfileViewModel] No user ID found - user is nil")
            await MainActor.run {
                self.isUploadingProfilePhoto = false
            }
            return 
        }
        
        let croppedImage = cropToSquare(newImage)
        
        do {
            let url = try await imageService.updateProfilePhoto(userId: userId, image: croppedImage)
            
            // Update the users table with the new profile photo URL
            do {
                try await updateProfilePhotoInDatabase(userId: userId, photoURL: url)
            } catch {
                print("⚠️ [ProfileViewModel] Failed to update database, but upload succeeded: \(error)")
            }
            
            // Update local user and userPicture on main thread
            await MainActor.run {
                self.user?.profilePhotoURL = url
                self.userPicture = croppedImage
                self.isUploadingProfilePhoto = false
            }
        } catch {
            print("❌ [ProfileViewModel] Failed to upload profile photo: \(error)")
            print("❌ [ProfileViewModel] Error type: \(type(of: error))")
            print("❌ [ProfileViewModel] Error details: \(error.localizedDescription)")
            
            // Revert the image on error and clear loading state
            await MainActor.run {
                self.isUploadingProfilePhoto = false
                // Keep the current userPicture or revert to previous state
                print("❌ [ProfileViewModel] Reverting image due to upload failure")
            }
        }
    }
    
     /// Update the users table with the new profile photo URL
     private func updateProfilePhotoInDatabase(userId: String, photoURL: URL) async throws {
        let supabase = await SupabaseManager.shared
        
        // Update the users table with the new profile_photo_url
        try await supabase.client
            .from("users")
            .update(["profile_photo_url": photoURL.absoluteString])
            .eq("id", value: userId)
            .execute()
        
    }
    
     private func cropToSquare(_ image: UIImage) -> UIImage {
         let cgImage = image.cgImage!
         let contextImage = UIImage(cgImage: cgImage)
         let contextSize = contextImage.size
        
         // Get the size of the square
         let size = min(contextSize.width, contextSize.height)
        
         // Calculate the crop rect
         let x = (contextSize.width - size) / 2
         let y = (contextSize.height - size) / 2
         let cropRect = CGRect(x: x * image.scale,
                             y: y * image.scale,
                             width: size * image.scale,
                             height: size * image.scale)
        
         // Create the cropped image
         if let croppedCGImage = cgImage.cropping(to: cropRect) {
             return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
         }
        
         return image
     }
    
     func toggleFollowUser(userId: String) {
        guard let currentUserId = user?.id else { return }
        
        // Store original state for potential rollback
        let originalFollowingState = userFollowing.contains(where: { $0.id == userId })
        let originalFollowingCount = followingCount
        let originalUserFollowing = userFollowing
        
        if userFollowing.contains(where: { $0.id == userId }) {
            // Optimistic update: immediately change UI
            DispatchQueue.main.async {
                self.userFollowing.removeAll { $0.id == userId }
                self.followingCount = max(0, self.followingCount - 1)
            }
            
            // Note: Friend tracking is now handled by PostgreSQL function - no need to update MapViewModel
            
            // Make the actual API call
            userService.unfollowUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if !success {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self?.userFollowing = originalUserFollowing
                        self?.followingCount = originalFollowingCount
                        // Show error alert
                        self?.showFollowError = true
                        self?.followErrorMessage = "Failed to unfollow user. Please try again."
                    }
                }
            }
        } else {
            // Optimistic update: immediately change UI
            DispatchQueue.main.async {
                self.followingCount += 1
            }
            
            // Make the actual API call
            userService.followUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if success {
                    // Fetch the ProfileData for the followed user and add to userFollowing
                    self?.userService.fetchUserById(userId: userId) { result in
                        if case .success(let profileData) = result {
                            DispatchQueue.main.async {
                                self?.userFollowing.append(profileData)
                                // Note: Friend tracking is now handled by PostgreSQL function
                            }
                        }
                    }
                } else {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self?.userFollowing = originalUserFollowing
                        self?.followingCount = originalFollowingCount
                        // Show error alert
                        self?.showFollowError = true
                        self?.followErrorMessage = "Failed to follow user. Please try again."
                    }
                }
            }
        }
    }
    
    /// Update local following state after external follow/unfollow action
    /// This does NOT make an API call - it only updates local state
    func updateFollowingState(userId: String, isFollowing: Bool) {
        if isFollowing {
            // Add to following list if not already there
            if !userFollowing.contains(where: { $0.id == userId }) {
                followingCount += 1
                // Fetch the user profile and add to following list
                userService.fetchUserById(userId: userId) { [weak self] result in
                    if case .success(let profileData) = result {
                        DispatchQueue.main.async {
                            self?.userFollowing.append(profileData)
                        }
                    }
                }
            }
        } else {
            // Remove from following list
            if userFollowing.contains(where: { $0.id == userId }) {
                userFollowing.removeAll { $0.id == userId }
                followingCount = max(0, followingCount - 1)
            }
        }
    }
    
    /// Update friend IDs in MapViewModel for viewport filtering
    // updateMapViewModelFriendIds removed - friend tracking is now handled by the PostgreSQL function
    
     private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
         let totalSize = CGSize(width: 80, height: 40)
         let singleCircleSize = CGSize(width: 40, height: 40)
         let renderer = UIGraphicsImageRenderer(size: totalSize)
        
         return renderer.image { context in
             let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
             let secondRect = CGRect(x: 15, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
             let thirdRect = CGRect(x: 30, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            
             func drawCircularImage(_ image: UIImage?, in rect: CGRect) {
                 guard let image = image else { return }
                 context.cgContext.saveGState()
                 let circlePath = UIBezierPath(ovalIn: rect)
                 circlePath.addClip()
                 image.draw(in: rect)
                 context.cgContext.setStrokeColor(UIColor.white.cgColor)
                 context.cgContext.setLineWidth(1.0)
                 context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
                 context.cgContext.restoreGState()
             }
            
             if image3 != nil { drawCircularImage(image3, in: thirdRect) }
             if image2 != nil { drawCircularImage(image2, in: secondRect) }
             if image1 != nil { drawCircularImage(image1, in: firstRect) }
         }
     }
    
     func isPlaceInList(listId: UUID, placeId: String) -> Bool {
         let listIdString = listId.uuidString
         let places = userListsPlaces[listIdString] ?? []
         return places.contains(placeId)
     }
    
    // MARK: - Add to List Functions
    
    /// Add a place to a lightweight list (current format)
    /// - Parameters:
    ///   - listId: The list ID to add the place to
    ///   - place: The place to add
    ///   - updatedCount: The new count after adding (caller owns state and does the math)
    func addPlaceToLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        guard let userId = userSession.currentUserId else { return }
        
        let placeId = place.id.uuidString
        
        // Create lightweight place object with added_by info for collaborative lists
        let lightweightPlace = LightweightPlace(
            place_id: placeId,
            name: place.name,
            latest_review_photo: place.photoUrls?.first,
            external_place_id: nil, // Not a TikTok external place
            tiktok_url: nil,
            added_by_user_id: userId,
            added_by_name: user?.fullName,
            added_by_photo_url: user?.profilePhotoURL?.absoluteString
        )
        
        var didInsert = false
        
        // Update local lightweightPlaceListPlaces
        if var existingPlaces = lightweightPlaceListPlaces[listId] {
            if !existingPlaces.contains(where: { $0.place_id == placeId }) {
                existingPlaces.append(lightweightPlace)
                lightweightPlaceListPlaces[listId] = existingPlaces
                didInsert = true
            }
        } else {
            lightweightPlaceListPlaces[listId] = [lightweightPlace]
            didInsert = true
        }
        
        if didInsert {
            if let finalCount = updatedCount {
                // Caller owns state and has already done the math - just store it
                lightweightPlaceListCounts[listId] = finalCount
            } else {
                // Legacy path: we own the state, so we do the math
                let startingCount = lightweightPlaceListCounts[listId]
                    ?? lightweightPlaceLists.first(where: { $0.list_id == listId })?.place_count
                    ?? 0
                lightweightPlaceListCounts[listId] = startingCount + 1
            }
        }
        
        // Update DetailPlaceViewModel's places dictionary for immediate UI update
        detailPlaceViewModel.places[placeId] = place
        
        // Add current user as saver so places appear on map with profile picture
        if detailPlaceViewModel.placeSavers[placeId] == nil {
            detailPlaceViewModel.placeSavers[placeId] = [userId]
        } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
            detailPlaceViewModel.placeSavers[placeId]!.append(userId)
        }
        
        // Recalculate map annotations to include the new place
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Persist to Supabase with added_by for collaborative list attribution
        Task {
            do {
                try await SupabaseUserService.shared.addPlaceToList(
                    listId: listId,
                    placeId: placeId,
                    addedBy: userId
                )
            } catch {
                print("❌ [ProfileViewModel] Failed to add place to list: \(error)")
            }
        }
    }
    
    /// Add a place to a list (old UUID-based format) - delegates to addPlaceToLightweightList
    /// DEPRECATED: Use addPlaceToLightweightList directly for new code
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        let listIdString = listId.uuidString
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }) else { return }

        // Delegate to new implementation for core functionality
        addPlaceToLightweightList(listId: listIdString, place: place)
        
        // Legacy-specific: Update old PlaceList format
        let placeForList = place.toPlace()
        var places = userListsPlaces[listIdString] ?? []
        if !places.contains(place.id.uuidString) {
            places.append(place.id.uuidString)
            userListsPlaces[listIdString] = places
        }
        
        if !userLists[listIndex].places.contains(where: { $0.id == place.id }) {
            userLists[listIndex].places.append(placeForList)
            placeListCounts[listId] = userLists[listIndex].places.count
        }
        
        // Legacy-specific: Update average coordinates and pagination
        recalculateAverageCoordinates(for: listId)
        resetListPagination(listId: listId)
    }
    
    /// Remove a place from a lightweight list (new format)
    /// Remove a place from a lightweight list
    /// - Parameters:
    ///   - listId: The list ID to remove the place from
    ///   - place: The place to remove
    ///   - updatedCount: The new count after removing (caller owns state and does the math)
    func removePlaceFromLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        guard let userId = userSession.currentUserId else {
            return
        }
        
        var didRemove = false
        
        // Update local lightweightPlaceListPlaces
        if var places = lightweightPlaceListPlaces[listId] {
            let originalCount = places.count
            places.removeAll { $0.place_id == place.id.uuidString }
            if places.count != originalCount {
                didRemove = true
            }
            lightweightPlaceListPlaces[listId] = places
        }
        
        if didRemove {
            if let finalCount = updatedCount {
                // Caller owns state and has already done the math - just store it
                lightweightPlaceListCounts[listId] = finalCount
            } else {
                // Legacy path: we own the state, so we do the math
                let startingCount = lightweightPlaceListCounts[listId]
                    ?? lightweightPlaceLists.first(where: { $0.list_id == listId })?.place_count
                    ?? 0
                lightweightPlaceListCounts[listId] = max(startingCount - 1, 0)
            }
        }
        
        // Remove current user as saver
        if var savers = detailPlaceViewModel.placeSavers[place.id.uuidString] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: place.id.uuidString)
            } else {
                detailPlaceViewModel.placeSavers[place.id.uuidString] = savers
            }
        }
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Persist to Supabase
        Task {
            do {
                try await SupabaseUserService.shared.removePlaceFromList(listId: listId, placeId: place.id.uuidString)
            } catch {
                print("❌ [ProfileViewModel] Failed to remove place from lightweight list: \(error)")
            }
        }
    }
    
    /// Merge TikTok data from an ExternalPlace into a DetailPlace (async)
    func mergeTikTokData(into detailPlace: DetailPlace, from externalPlace: ExternalPlace) async -> DetailPlace {
        // Create a copy of the DetailPlace with TikTok data merged in
        var mergedPlace = detailPlace

        // If the external place has a TikTok URL, fetch metadata from cache
        if let url = externalPlace.url, !url.isEmpty {
            if let tikTokVideo = await TikTokMetadataCache.shared.getMetadata(for: url) {
                mergedPlace.tikTokVideos = [tikTokVideo]
            }
        }

        return mergedPlace
    }

     func removePlaceFromList(listId: UUID, place: DetailPlace) {
         let listIdString = listId.uuidString
         guard
             var places = userListsPlaces[listIdString],
             let index = places.firstIndex(of: place.id.uuidString),
             let userId = userSession.currentUserId,
             let list = userLists.first(where: { $0.id == listId })
         else {
             return
         }

         places.remove(at: index)
         userListsPlaces[listIdString] = places
         
         let placeForList = place.toPlace()

         placeService.removePlaceFromList(userId: userId, listId: list.id.uuidString, placeId: placeForList.id.uuidString) { error in
             if let error = error {
                 print("❌ Error removing place from list: \(error)")
             }
         }
         
         // Recalculate average coordinates for this list
         recalculateAverageCoordinates(for: listId)
         
         // Reset pagination to reflect the removed place
         resetListPagination(listId: listId)
         
         // Skip sorting for individual place removals to avoid frequent re-sorting
     }
    
    /// Adds a place to favorites with server-side validation.
    /// Uses FavoritesService for atomic check-and-insert to prevent race conditions.
    func addFavoritePlace(place: DetailPlace) {
        guard let userId = userSession.currentUserId else {
            print("⚠️ [ProfileViewModel] Cannot add favorite: no user ID")
            return
        }
        
        let placeId = place.id.uuidString
        
        // Quick client-side check (server will also validate)
        if lightweightFavorites.contains(where: { $0.place_id == placeId }) {
            return
        }
        
        // Optimistic UI update - add immediately for responsive UX
        let newFavorite = FavoritePlace(
            place_id: placeId,
            name: place.name,
            latest_review_photo: place.photoUrls?.first
        )
        lightweightFavorites.append(newFavorite)
        
        // Also update legacy userFavorites array
        if !userFavorites.contains(placeId) {
            userFavorites.append(placeId)
        }
        
        // Update placeSavers for map display
        updatePlaceSavers(placeId: placeId, userId: userId, isAdding: true)
        
        // Persist using FavoritesService (server-side validation)
        Task {
            let result = await FavoritesService.shared.addFavorite(userId: userId, placeId: placeId)
            
            await MainActor.run {
                switch result {
                case .success:
                    // Success - optimistic update was correct
                    self.detailPlaceViewModel.calculateAnnotationPlaces()
                    
                case .maxLimit:
                    // Server says max limit - revert and show alert
                    print("⚠️ [ProfileViewModel] Server rejected: max favorites reached")
                    self.revertFavoriteAdd(placeId: placeId, userId: userId)
                    self.showMaxFavoritesAlert = true
                    
                case .duplicate:
                    // Already favorited on server - keep local state as is
                    break
                    
                case .error(let error):
                    // Error - revert optimistic update
                    print("❌ [ProfileViewModel] Error adding favorite: \(error)")
                    self.revertFavoriteAdd(placeId: placeId, userId: userId)
                }
            }
        }
    }
    
    /// Reverts an optimistic favorite add
    private func revertFavoriteAdd(placeId: String, userId: String) {
        lightweightFavorites.removeAll { $0.place_id == placeId }
        userFavorites.removeAll { $0 == placeId }
        updatePlaceSavers(placeId: placeId, userId: userId, isAdding: false)
    }
    
    /// Updates placeSavers dictionary for map display
    private func updatePlaceSavers(placeId: String, userId: String, isAdding: Bool) {
        if isAdding {
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
        } else {
            detailPlaceViewModel.placeSavers[placeId]?.removeAll { $0 == userId }
            if detailPlaceViewModel.placeSavers[placeId]?.isEmpty == true {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            }
        }
    }
    
    /// Removes a place from favorites.
    func removeFavoritePlace(place: DetailPlace) {
        guard let userId = userSession.currentUserId else {
            print("⚠️ [ProfileViewModel] Cannot remove favorite: no user ID")
            return
        }
        
        let placeId = place.id.uuidString
        
        // Store for potential revert
        let removedFavorite = lightweightFavorites.first { $0.place_id == placeId }
        
        // Optimistic UI update - remove immediately
        lightweightFavorites.removeAll { $0.place_id == placeId }
        userFavorites.removeAll { $0 == placeId }
        
        // Persist using FavoritesService
        Task {
            do {
                try await FavoritesService.shared.removeFavorite(userId: userId, placeId: placeId)
            } catch {
                // Revert optimistic update on failure
                print("❌ [ProfileViewModel] Error removing favorite: \(error)")
                await MainActor.run {
                    if let favorite = removedFavorite {
                        self.lightweightFavorites.append(favorite)
                    }
                    if !self.userFavorites.contains(placeId) {
                        self.userFavorites.append(placeId)
                    }
                }
            }
        }
    }
    
    /// Checks if a place is in the user's favorites.
    func isPlaceFavorite(placeId: String) -> Bool {
        return lightweightFavorites.contains(where: { $0.place_id == placeId }) || userFavorites.contains(placeId)
    }
    
    // MARK: - Place Notes
    
    func savePlaceNote(for placeId: String, note: String?, link: String?) {
        guard let userId = userSession.currentUserId else { return }
        
        let placeNote = PlaceNote(placeId: placeId, userId: userId, note: note, link: link)
        
        userService.savePlaceNote(note: placeNote) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.placeNotes[placeId] = placeNote
                }
            } else if let error = error {
                print("Error saving place note: \(error.localizedDescription)")
            }
        }
    }
    
    func loadPlaceNote(for placeId: String) {
        guard let userId = userSession.currentUserId else { return }
        
        userService.fetchPlaceNote(userId: userId, placeId: placeId) { [weak self] placeNote, error in
            DispatchQueue.main.async {
                if let placeNote = placeNote {
                    self?.placeNotes[placeId] = placeNote
                }
            }
        }
    }
    
    func deletePlaceNote(for placeId: String) {
        guard let userId = userSession.currentUserId,
              let placeNote = placeNotes[placeId] else { return }
        
        userService.deletePlaceNote(userId: userId, placeId: placeNote.placeId) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.placeNotes.removeValue(forKey: placeId)
                }
            } else if let error = error {
                print("Error deleting place note: \(error.localizedDescription)")
            }
        }
    }
    
    func getPlaceNote(for placeId: String) -> PlaceNote? {
        return placeNotes[placeId]
    }
    
    // MARK: - TikTok Place Flagging
    
    func flagTikTokPlace(for placeId: String, flagType: TikTokPlaceFlagType, tikTokUrl: String? = nil, userComment: String? = nil) {
        guard let userId = userSession.currentUserId else { return }
        
        let flag = TikTokPlaceFlag(
            placeId: placeId,
            userId: userId,
            flagType: flagType,
            tikTokUrl: tikTokUrl,
            userComment: userComment
        )
        
        userService.saveTikTokPlaceFlag(flag: flag) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.tikTokPlaceFlags[placeId] = flag
                }
            } else if let error = error {
                print("Error saving TikTok place flag: \(error.localizedDescription)")
            }
        }
    }
    
    func loadTikTokPlaceFlag(for placeId: String) {
        guard let userId = userSession.currentUserId else { return }
        
        userService.hasUserFlaggedPlace(userId: userId, placeId: placeId) { [weak self] flag, error in
            DispatchQueue.main.async {
                if let flag = flag {
                    self?.tikTokPlaceFlags[placeId] = flag
                }
            }
        }
    }
    
    func removeTikTokPlaceFlag(for placeId: String) {
        guard let userId = userSession.currentUserId,
              let flag = tikTokPlaceFlags[placeId] else { return }
        
        userService.deleteTikTokPlaceFlag(userId: userId, placeId: placeId) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.tikTokPlaceFlags.removeValue(forKey: placeId)
                }
            } else if let error = error {
                print("Error deleting TikTok place flag: \(error.localizedDescription)")
            }
        }
    }
    
    func getTikTokPlaceFlag(for placeId: String) -> TikTokPlaceFlag? {
        return tikTokPlaceFlags[placeId]
    }
    
    func hasFlaggedTikTokPlace(placeId: String) -> Bool {
        return tikTokPlaceFlags[placeId] != nil
    }
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) async -> Result<PlaceList, Error> {
        guard let userId = userSession.currentUserId else { 
            return .failure(NSError(domain: "ProfileViewModel", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "No user session"]))
        }
        
        do {
            let createdList = try await SupabasePlaceService.shared.createNewList(
                userId: userId,
                name: name,
                city: city,
                emoji: emoji,
                image: image
            )
            
            // Update old format (for backward compatibility)
            userLists.append(createdList)
            sortListsByDistance()
            setRecentlyCreatedList(createdList.id)
            
            // Add new list to top of lightweightPlaceLists for immediate UI update
            let lightweightList = LightweightPlaceList(
                list_id: createdList.id.uuidString,
                name: createdList.name,
                is_public: false,
                image: createdList.image,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date()),
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
            lightweightPlaceLists.insert(lightweightList, at: 0)
            
            // Refresh lightweight place lists to include the new list
            // Use current location if available, otherwise use default page 1
            if let location = locationManager.currentLocation?.coordinate {
                do {
                    let lists = try await SupabaseUserService.shared.fetchPlaceListsByProximity(
                        userId: userId,
                        userLatitude: location.latitude,
                        userLongitude: location.longitude,
                        page: 1,
                        pageSize: 6
                    )
                    // Merge: keep new list at top, then add others (avoiding duplicates)
                    var merged = [lightweightList]
                    merged.append(contentsOf: lists.filter { $0.list_id != lightweightList.list_id })
                    lightweightPlaceLists = merged
                    placeListsCurrentPage = 1
                    hasMorePlaceLists = lists.count >= 6
                } catch {
                    // Non-critical error - list was already added locally
                }
            }
            
            return .success(createdList)
        } catch {
            return .failure(error)
        }
    }
    
     func removePlaceList(placeList: PlaceList) {
         if let index = userLists.firstIndex(where: { $0.id == placeList.id }) {
             userLists.remove(at: index)
             sortListsByDistance() // Sort lists by distance after removing list
             guard let currentUserId = userSession.currentUserId else { return }
             placeService.deleteList(userId: currentUserId, listId: placeList.id.uuidString) { error in
                 if error != nil {
                     // Re-add the list if deletion failed
                     self.userLists.append(placeList)
                     self.sortListsByDistance()
                 }
                 // No need to sort on success - already sorted above
             }
         }
     }

    
    
     // Returns unique users who saved a place, excluding the current logged-in user
     func getUniquePlaceSaversExcludingCurrentUser(forPlaceId placeId: String) -> [ProfileData] {
         guard let userIds = detailPlaceViewModel.placeSavers[placeId], let currentUserId = user?.id else { return [] }
         
         // Filter out the current user and map to ProfileData in userFollowing
         let uniqueUsers = userIds
             .filter { $0 != currentUserId }
             .compactMap { userId in
                 userFollowing.first(where: { $0.id == userId })
             }
         
         return uniqueUsers
     }
    
     func isPlaceInAnyList(placeId: String) -> Bool {
         // Check if current user is in placeSavers for this place
         // placeSavers is consistently updated when places are added/removed from lists
         guard let userId = userSession.currentUserId else { return false }
         return detailPlaceViewModel.placeSavers[placeId]?.contains(userId) ?? false
     }

    /// Returns a dictionary mapping each PlaceList's id to the count of places in that list
    func placeCountsForAllLists() -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for list in userLists {
            counts[list.id] = list.places.count
        }
        return counts
    }

    /// Returns the count of places in the PlaceList with the given id, or 0 if not found
    func placeCount(forListId listId: UUID) -> Int {
        return userLists.first(where: { $0.id == listId })?.places.count ?? 0
    }
    
    func refreshUserPlaces() async {
        // Combine all place IDs from favorites and all lists, then de-duplicate
        var allPlaceIds = Set(userFavorites)
        for list in userListsPlaces.values {
            allPlaceIds.formUnion(list)
        }
        await detailPlaceViewModel.refreshPlaces(detailPlaces: Array(allPlaceIds))
    }

    /// Load initial reviewed places (server-side pagination like TikToks)
    func loadMyReviewedPlacesWithPagination() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot load reviewed places: no user ID")
            return
        }
        
        // Don't reload if already loading, if we have data, or if we already attempted (prevents infinite loop with no reviews)
        guard !isLoadingReviewedPlaces && lightweightReviewedPlaces.isEmpty && !hasAttemptedInitialReviewsLoad else {
            return
        }
        
        await loadInitialReviewedPlaces()
    }
    
    /// Load initial reviewed places from database (server-side pagination)
    private func loadInitialReviewedPlaces() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot load initial reviewed places: no user ID")
            return
        }
        
        isLoadingReviewedPlaces = true
        hasAttemptedInitialReviewsLoad = true // Mark that we've attempted the initial load
        
        defer {
            isLoadingReviewedPlaces = false
        }
        
        do {
            // Fetch first page of lightweight reviewed places and total count in parallel
            async let placesTask = userService.fetchUserReviewedPlaces(userId: userId, limit: 8, offset: 0)
            async let countTask = SupabaseUserService.shared.getNumberReviewedPlaces(forUserId: userId)
            
            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0
            
            // Update state: replace existing places and update hasMore flag
            lightweightReviewedPlaces = lightweightPlaces
            totalReviewedPlacesCount = totalCount
            hasMoreReviews = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
            
            // Load full place details for display (non-blocking like TikTok prefetch)
            Task {
                await loadPlaceDetailsForReviews(lightweightPlaces, userId: userId)
            }
        } catch {
            print("❌ [ProfileViewModel] Error loading initial reviewed places: \(error.localizedDescription)")
            // Set hasMore to false on error to prevent infinite retry loops
            hasMoreReviews = false
        }
    }

    /// Load more reviewed places (pagination) - server-side like TikToks
    func loadMoreMyReviews() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot load more reviewed places: no user ID")
            return
        }
        
        // Guard: prevent multiple simultaneous loads and check if more data is available
        guard !isLoadingMoreReviews && hasMoreReviews else {
            return
        }
        
        // Calculate offset based on current count
        let offset = lightweightReviewedPlaces.count
        
        isLoadingMoreReviews = true
        
        defer {
            isLoadingMoreReviews = false
        }
        
        do {
            // Fetch next page of lightweight reviewed places
            let lightweightPlaces = try await userService.fetchUserReviewedPlaces(userId: userId, limit: 8, offset: offset)
            
            // Update state: append new places and update hasMore flag
            // ⚠️ CRITICAL: Deduplicate to prevent SwiftUI rendering issues
            let existingIds = Set(lightweightReviewedPlaces.map { $0.id })
            let newUniquePlaces = lightweightPlaces.filter { !existingIds.contains($0.id) }
            
            if !newUniquePlaces.isEmpty {
                lightweightReviewedPlaces.append(contentsOf: newUniquePlaces)
                let duplicateCount = lightweightPlaces.count - newUniquePlaces.count
                if duplicateCount > 0 {
                    print("⚠️ [ProfileViewModel] Filtered \(duplicateCount) duplicate reviewed places")
                }
            } else if !lightweightPlaces.isEmpty {
                print("⚠️ [ProfileViewModel] All \(lightweightPlaces.count) reviewed places were duplicates - potential pagination issue")
            }
            
            // Update hasMore flag: false if empty or if we got less than a full page
            hasMoreReviews = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
            
            // Load full place details for display (non-blocking like TikTok prefetch)
            Task {
                await loadPlaceDetailsForReviews(newUniquePlaces, userId: userId)
            }
        } catch {
            print("❌ [ProfileViewModel] Error loading more reviewed places: \(error.localizedDescription)")
            // Set hasMore to false on error to prevent infinite retry loops
            hasMoreReviews = false
        }
    }
    
    /// Load full place details for reviewed places
    private func loadPlaceDetailsForReviews(_ lightweightPlaces: [LightweightPlace], userId: String) async {
        for place in lightweightPlaces {
            let placeId = place.place_id
            
            // Load place details if not already loaded
            if detailPlaceViewModel.places[placeId] == nil {
                do {
                    let detailPlace = try await placeService.fetchPlace(withId: placeId)
                    await MainActor.run {
                        detailPlaceViewModel.places[placeId] = detailPlace
                        detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    }
                } catch {
                    print("❌ [ProfileViewModel] Failed to load place \(placeId): \(error.localizedDescription)")
                }
            }
            
            // Add current user as saver so reviewed places appear on map with profile picture
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
        }
        
        // Recalculate map annotations to include new reviewed places
        detailPlaceViewModel.calculateAnnotationPlaces()
    }
    
    /// Fetch post images for a batch of places to enhance the place display
    private func fetchPostImagesForPlaces(_ placeIds: [String], userId: String) async {
        // Collect all image URLs first
        var imageUrlsToLoad: [(placeId: String, imageUrl: String)] = []
        
        // Fetch posts for these places to get images
        for placeId in placeIds {
            do {
                // Get the most recent post for this place by this user
                let (posts, _) = try await postService.fetchPosts(placeId: placeId, latestOnly: false)
                let userPosts = posts.filter { $0.userId == userId }
                
                if let mostRecentPost = userPosts.first(where: { !$0.images.isEmpty }),
                   let imageUrl = mostRecentPost.images.first,
                   detailPlaceViewModel.placeImages[placeId] == nil {
                    imageUrlsToLoad.append((placeId: placeId, imageUrl: imageUrl))
                }
            } catch {
                print("⚠️ [ProfileViewModel] Failed to fetch post images for place \(placeId): \(error.localizedDescription)")
            }
        }
        
        // Load all images in parallel
        if !imageUrlsToLoad.isEmpty {
            // Loading post images in parallel
            await withTaskGroup(of: Void.self) { group in
                for (placeId, imageUrl) in imageUrlsToLoad {
                    group.addTask {
                        await self.loadImageFromURL(imageUrl: imageUrl, placeId: placeId)
                    }
                }
            }
        }
    }

    /// Get reviewed places for display (server-side pagination)
    func getMyReviewedPlaces() -> [DetailPlace] {
        return lightweightReviewedPlaces.compactMap { detailPlaceViewModel.places[$0.place_id] }
    }
    
    /// Load image directly from URL and add to placeImages
    private func loadImageFromURL(imageUrl: String, placeId: String) async {
        // Block Firebase Storage URLs (migrated to Supabase)
        if imageUrl.contains("firebasestorage.googleapis.com") {
            return
        }
        
        guard let url = URL(string: imageUrl) else {
            print("⚠️ [ProfileViewModel] Invalid image URL: \(imageUrl)")
            return
        }
        
        do {
            // Use a more efficient URLSession configuration for image loading
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0  // ✅ Reduced timeout
            config.timeoutIntervalForResource = 10.0  // ✅ Reduced timeout
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    detailPlaceViewModel.placeImages[placeId] = image
                    // Loaded review image for place
                }
            } else {
                print("⚠️ [ProfileViewModel] Failed to create UIImage from data for place \(placeId)")
            }
        } catch {
            print("⚠️ [ProfileViewModel] Failed to load image from URL for place \(placeId): \(error.localizedDescription)")
        }
    }

    /// Reset reviewed places pagination state (server-side pagination)
    /// Single source of truth for all reviewed places state - ensures clean reload
    func resetMyReviewedPlacesPagination() {
        isLoadingReviewedPlaces = false
        isLoadingMoreReviews = false
        hasMoreReviews = true
        lightweightReviewedPlaces = []
        hasAttemptedInitialReviewsLoad = false  // Critical: allow fresh reload on next view appear
    }

    /// Get the total count of reviewed places (server-side pagination)
    var reviewedPlacesCount: Int {
        return lightweightReviewedPlaces.count
    }
    
    // User posts for display in My Places
    @Published var userPosts: [PlacePost] = []
    @Published var isLoadingUserPosts: Bool = false
    
    /// Load the last 8 posts made by the user
    func loadUserPosts() async {
        guard let userId = user?.id else { return }
        
        await MainActor.run {
            isLoadingUserPosts = true
        }
        
        do {
            // Fetch all posts for the user
            let allPosts = try await postService.fetchUserPosts(userId: userId)
            
            // Sort by timestamp (most recent first) and take the last 8
            let sortedPosts = allPosts.sorted { $0.timestamp > $1.timestamp }
            let last8Posts = Array(sortedPosts.prefix(8))
            
            await MainActor.run {
                userPosts = last8Posts
                isLoadingUserPosts = false
            }
        } catch {
            print("❌ [ProfileViewModel] Error loading user posts: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingUserPosts = false
            }
        }
    }
    
    // MARK: - TikTok Places Refresh After Import
    
    /// Refresh TikTok places list after a successful import
    func refreshTikTokPlacesAfterImport() {
        // Reload lightweight external places to show new TikTok place in tiles
        Task {
            await reloadLightweightExternalPlaces()
        }
    }
    
    /// Reload lightweight external places from the database
    private func reloadLightweightExternalPlaces() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot reload lightweight external places: no user ID")
            return
        }
        
        await MainActor.run {
            isLoadingTikTokPlaces = true
        }
        
        do {
            // Fetch first page of lightweight external places and total count in parallel
            async let placesTask = userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: 0)
            async let countTask = userService.getNumberExternalPlaces(forUserId: userId)
            
            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0
            
            // Prefetch TikTok metadata for all TikTok URLs
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
            }
            
            await MainActor.run {
                lightweightExternalPlaces = lightweightPlaces
                totalExternalPlacesCount = totalCount
                hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
                isLoadingTikTokPlaces = false
            }
        } catch {
            print("❌ [ProfileViewModel] Error reloading lightweight external places: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingTikTokPlaces = false
                hasMoreExternalPlaces = false
            }
        }
    }
    
    // MARK: - External Places Pagination (MVVM Architecture)
    
    /// Load initial external places (TikTok places) - lightweight with pagination
    /// This method handles the first page load when the TikTok tab appears
    func loadInitialExternalPlaces() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot load initial external places: no user ID")
            return
        }
        
        // Don't reload if already loading or if we have data
        guard !isLoadingTikTokPlaces && lightweightExternalPlaces.isEmpty else {
            return
        }
        
        isLoadingTikTokPlaces = true
        
        defer {
            isLoadingTikTokPlaces = false
        }
        
        do {
            // Fetch first page of lightweight external places and total count in parallel
            async let placesTask = userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: 0)
            async let countTask = userService.getNumberExternalPlaces(forUserId: userId)
            
            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0
            
            // Prefetch TikTok metadata for all TikTok URLs (non-blocking)
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                }
            }
            
            // Update state: replace existing places and update hasMore flag
            lightweightExternalPlaces = lightweightPlaces
            totalExternalPlacesCount = totalCount
            hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileViewModel] Error loading initial external places: \(error.localizedDescription)")
            // Set hasMore to false on error to prevent infinite retry loops
            hasMoreExternalPlaces = false
        }
    }
    
    /// Load more external places (pagination) - MVVM architecture
    /// This method handles loading additional pages when user scrolls to the end
    func loadMoreExternalPlaces() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot load more external places: no user ID")
            return
        }
        
        // Guard: prevent multiple simultaneous loads and check if more data is available
        guard !isLoadingMoreExternalPlaces && hasMoreExternalPlaces else {
            return
        }
        
        // Calculate offset based on current count
        let offset = lightweightExternalPlaces.count
        
        isLoadingMoreExternalPlaces = true
        
        defer {
            isLoadingMoreExternalPlaces = false
        }
        
        do {
            // Fetch next page of lightweight external places
            let lightweightPlaces = try await userService.fetchUserExternalPlaces(userId: userId, limit: 8, offset: offset)
            
            // Prefetch TikTok metadata for all TikTok URLs (non-blocking)
            let tiktokUrls = lightweightPlaces.compactMap { $0.tiktok_url }.filter { !$0.isEmpty }
            if !tiktokUrls.isEmpty {
                Task {
                    await TikTokMetadataCache.shared.prefetchMetadata(for: tiktokUrls)
                }
            }
            
            // Update state: append new places and update hasMore flag
            // ⚠️ CRITICAL: Deduplicate to prevent SwiftUI rendering issues
            let existingIds = Set(lightweightExternalPlaces.map { $0.id })
            let newUniquePlaces = lightweightPlaces.filter { !existingIds.contains($0.id) }
            
            if !newUniquePlaces.isEmpty {
                lightweightExternalPlaces.append(contentsOf: newUniquePlaces)
                let duplicateCount = lightweightPlaces.count - newUniquePlaces.count
                if duplicateCount > 0 {
                    print("⚠️ [ProfileViewModel] Filtered \(duplicateCount) duplicate places")
                }
            } else if !lightweightPlaces.isEmpty {
                print("⚠️ [ProfileViewModel] All \(lightweightPlaces.count) places were duplicates - potential pagination issue")
            }
            
            // Update hasMore flag: false if empty or if we got less than a full page
            hasMoreExternalPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileViewModel] Error loading more external places: \(error.localizedDescription)")
            // Set hasMore to false on error to prevent infinite retry loops
            hasMoreExternalPlaces = false
        }
    }
    
    // MARK: - My Places Pagination (MVVM Architecture)
    
    /// Load initial my places (created places) - lightweight with pagination
    /// This method handles the first page load when the My Places popup appears
    func loadInitialMyPlaces() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot load initial my places: no user ID")
            return
        }
        
        // Don't reload if already loading or if we have data
        guard !isMyPlacesLoading && lightweightMyPlaces.isEmpty else {
            return
        }
        
        isMyPlacesLoading = true
        
        defer {
            isMyPlacesLoading = false
        }
        
        do {
            // Fetch first page of lightweight places and total count in parallel
            async let placesTask = userService.fetchUserCreatedPlaces(userId: userId, limit: 8, offset: 0)
            async let countTask = userService.getNumberCreatedPlaces(forUserId: userId)
            
            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0
            
            // Update state: replace existing places and update hasMore flag
            lightweightMyPlaces = lightweightPlaces
            myPlaces = lightweightPlaces.map { $0.place_id }
            totalMyPlacesCount = totalCount
            hasMoreMyPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
            
            // Add the current user as a saver for their own places (for map display)
            for place in lightweightPlaces {
                let placeId = place.place_id
                if detailPlaceViewModel.placeSavers[placeId] == nil {
                    detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
        } catch {
            print("❌ [ProfileViewModel] Error loading initial my places: \(error.localizedDescription)")
            hasMoreMyPlaces = false
        }
    }
    
    /// Load more my places (pagination) - MVVM architecture
    /// This method handles loading additional pages when user scrolls to the end
    func loadMoreMyPlaces() async {
        guard let userId = user?.id else {
            print("⚠️ [ProfileViewModel] Cannot load more my places: no user ID")
            return
        }
        
        // Guard: prevent multiple simultaneous loads and check if more data is available
        guard !isLoadingMoreMyPlaces && hasMoreMyPlaces else {
            return
        }
        
        // Calculate offset based on current count
        let offset = lightweightMyPlaces.count
        
        isLoadingMoreMyPlaces = true
        
        defer {
            isLoadingMoreMyPlaces = false
        }
        
        do {
            // Fetch next page of lightweight places
            let lightweightPlaces = try await userService.fetchUserCreatedPlaces(userId: userId, limit: 8, offset: offset)
            
            // Update state: append new places and update hasMore flag
            // ⚠️ CRITICAL: Deduplicate to prevent SwiftUI rendering issues
            let existingIds = Set(lightweightMyPlaces.map { $0.id })
            let newUniquePlaces = lightweightPlaces.filter { !existingIds.contains($0.id) }
            
            if !newUniquePlaces.isEmpty {
                lightweightMyPlaces.append(contentsOf: newUniquePlaces)
                myPlaces.append(contentsOf: newUniquePlaces.map { $0.place_id })
                
                // Add the current user as a saver for their own places (for map display)
                for place in newUniquePlaces {
                    let placeId = place.place_id
                    if detailPlaceViewModel.placeSavers[placeId] == nil {
                        detailPlaceViewModel.placeSavers[placeId] = [userId]
                    } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                        detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                    }
                }
                
                let duplicateCount = lightweightPlaces.count - newUniquePlaces.count
                if duplicateCount > 0 {
                    print("⚠️ [ProfileViewModel] Filtered \(duplicateCount) duplicate places")
                }
            } else if !lightweightPlaces.isEmpty {
                print("⚠️ [ProfileViewModel] All \(lightweightPlaces.count) places were duplicates - potential pagination issue")
            }
            
            // Update hasMore flag: false if empty or if we got less than a full page
            hasMoreMyPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= 8
        } catch {
            print("❌ [ProfileViewModel] Error loading more my places: \(error.localizedDescription)")
            hasMoreMyPlaces = false
        }
    }
    
    // MARK: - TikTok Place Deletion
    
    func deleteTikTokPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        guard let userId = user?.id else {
            completion(false)
            return
        }
        
        let placeId = place.id.uuidString
        
        // Remove from local state first (optimistic update)
        if let index = allTikTokPlaceIds.firstIndex(of: placeId) {
            allTikTokPlaceIds.remove(at: index)
        }
        if let index = loadedTikTokPlaceIds.firstIndex(of: placeId) {
            loadedTikTokPlaceIds.remove(at: index)
        }
        
        // Remove from userExternalPlaces
        userExternalPlaces.removeValue(forKey: placeId)
        
        // Remove from placeSavers (so it doesn't appear on map)
        if var savers = detailPlaceViewModel.placeSavers[placeId] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            } else {
                detailPlaceViewModel.placeSavers[placeId] = savers
            }
        }
        
        // Remove from places dictionary
        detailPlaceViewModel.places.removeValue(forKey: placeId)
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Call backend to delete the TikTok place
        userService.deleteTikTokPlace(userId: userId, placeId: placeId) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileViewModel] Error deleting TikTok place: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    /// Delete a TikTok place using LightweightPlace (for popup views)
    /// Single Responsibility: Remove TikTok place from local state and persist to backend
    func deleteTikTokPlace(_ place: LightweightPlace) {
        guard let userId = user?.id else { return }
        
        let placeId = place.place_id
        
        // Optimistic update: Remove from all local collections immediately
        removeFromLocalTikTokState(placeId: placeId, userId: userId)
        
        // Persist deletion to backend
        userService.deleteTikTokPlace(userId: userId, placeId: placeId) { error in
            if let error = error {
                print("❌ [ProfileViewModel] Error deleting TikTok place: \(error.localizedDescription)")
                // Note: Could add revert logic here if needed
            }
        }
    }
    
    /// Helper: Remove TikTok place from all local state collections
    /// Single Responsibility: Local state cleanup only
    private func removeFromLocalTikTokState(placeId: String, userId: String) {
        // Remove from lightweight places array
        lightweightExternalPlaces.removeAll { $0.place_id == placeId }
        
        // Remove from ID tracking collections
        allTikTokPlaceIds.removeAll { $0 == placeId }
        loadedTikTokPlaceIds.removeAll { $0 == placeId }
        userExternalPlaces.removeValue(forKey: placeId)
        
        // Remove from placeSavers (so it doesn't appear on map)
        if var savers = detailPlaceViewModel.placeSavers[placeId] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            } else {
                detailPlaceViewModel.placeSavers[placeId] = savers
            }
        }
        
        // Remove from places dictionary
        detailPlaceViewModel.places.removeValue(forKey: placeId)
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
    }
    
    private func revertTikTokPlaceDeletion(_ place: DetailPlace) {
        let placeId = place.id.uuidString
        
        // Re-add to local state
        if !allTikTokPlaceIds.contains(placeId) {
            allTikTokPlaceIds.append(placeId)
            allTikTokPlaceIds.sort { placeId1, placeId2 in
                // Sort by date (most recent first)
                let place1 = userExternalPlaces[placeId1]
                let place2 = userExternalPlaces[placeId2]
                return (place1?.addedAt ?? Date.distantPast) > (place2?.addedAt ?? Date.distantPast)
            }
        }
        
        if !loadedTikTokPlaceIds.contains(placeId) {
            loadedTikTokPlaceIds.append(placeId)
        }
        
        // Re-add to placeSavers
        if let userId = user?.id {
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
        }
        
        // Re-add to places dictionary
        detailPlaceViewModel.places[placeId] = place
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
    }
    
    // MARK: - Reviewed Places Access
    
    /// Cached set of place IDs the user has reviewed (for unvisited filtering)
    /// Loaded on-demand when needed for a specific set of places
    @Published var verifiedReviewedPlaceIds: Set<String> = []
    @Published var isLoadingVerifiedReviewedIds: Bool = false
    
    /// Check if user has reviewed a place (quick check against paginated data)
    /// Note: For accurate filtering, use loadVerifiedReviewedPlaceIds() first
    func hasReviewedPlace(placeId: String) -> Bool {
        return lightweightReviewedPlaces.contains { $0.place_id == placeId }
    }
    
    /// Check if user has reviewed a place (using database-verified IDs)
    /// More accurate than hasReviewedPlace() - use after calling loadVerifiedReviewedPlaceIds()
    func hasVerifiedReviewedPlace(placeId: String) -> Bool {
        return verifiedReviewedPlaceIds.contains(placeId)
    }
    
    /// Load verified reviewed place IDs from database for accurate filtering
    /// Call this with the place IDs you want to filter, then use hasVerifiedReviewedPlace()
    func loadVerifiedReviewedPlaceIds(for placeIds: [String]) async {
        guard let userId = user?.id else { return }
        guard !placeIds.isEmpty else { return }
        guard !isLoadingVerifiedReviewedIds else { return }
        
        isLoadingVerifiedReviewedIds = true
        
        do {
            let ids = try await SupabaseReviewService.shared.getReviewedPlaceIds(
                userId: userId,
                placeIds: placeIds
            )
            verifiedReviewedPlaceIds = ids
        } catch {
            print("❌ [ProfileViewModel] Error loading verified reviewed IDs: \(error)")
        }
        
        isLoadingVerifiedReviewedIds = false
    }
    
    /// Clear verified reviewed place IDs (call when switching contexts)
    func clearVerifiedReviewedPlaceIds() {
        verifiedReviewedPlaceIds = []
    }
    
    // MARK: - List Sorting by Distance
    
    private var hasPerformedInitialSort = false
    
    /// Calculates the distance from the user's current location to a list using pre-calculated average coordinates
    private func calculateDistanceToList(_ list: PlaceList) -> Double {
        guard let currentLocation = locationManager.currentLocation else { 
            return Double.infinity 
        }
        
        // Use pre-calculated average coordinates if available (much faster!)
        if let averageCoordinate = list.averageCoordinate {
            let listLocation = CLLocation(
                latitude: averageCoordinate.latitude,
                longitude: averageCoordinate.longitude
            )
            let distance = currentLocation.distance(from: listLocation)
            return distance
        }
        
        // Fallback to calculating average distance from individual places (slower)
        let listPlaceIds = userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { return Double.infinity }
        
        var totalDistance: Double = 0
        var validPlaceCount: Int = 0
        
        for placeId in listPlaceIds {
            if let detailPlace = detailPlaceViewModel.places[placeId] {
                if let placeCoordinate = detailPlace.coordinate {
                    let placeLocation = CLLocation(
                        latitude: placeCoordinate.latitude,
                        longitude: placeCoordinate.longitude
                    )
                    
                    let distance = currentLocation.distance(from: placeLocation)
                    totalDistance += distance
                    validPlaceCount += 1
                } else {
                }
            } else {
            }
        }
        
        let averageDistance = validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
        
        return averageDistance
    }
    
    /// Recalculates the average coordinates for a specific list
    private func recalculateAverageCoordinates(for listId: UUID) {
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }),
              let placeIds = userListsPlaces[listId.uuidString] else {
            return
        }
        
        var totalLatitude: Double = 0
        var totalLongitude: Double = 0
        var validPlaceCount: Int = 0
        
        // Calculate average from all places in the list
        for placeId in placeIds {
            if let detailPlace = detailPlaceViewModel.places[placeId],
               let coordinate = detailPlace.coordinate {
                totalLatitude += coordinate.latitude
                totalLongitude += coordinate.longitude
                validPlaceCount += 1
            }
        }
        
        // Update the list's average coordinates
        if validPlaceCount > 0 {
            let averageLatitude = totalLatitude / Double(validPlaceCount)
            let averageLongitude = totalLongitude / Double(validPlaceCount)
            
            userLists[listIndex].averageCoordinate = CLLocationCoordinate2D(
                latitude: averageLatitude,
                longitude: averageLongitude
            )
            userLists[listIndex].lastCoordinateUpdate = Date()
            
            
            // Update in Firestore
            if let userId = userSession.currentUserId {
                Task {
                    await updateListAverageCoordinates(userId: userId, listId: listId, averageCoordinate: userLists[listIndex].averageCoordinate!)
                }
            }
        } else {
            // No valid coordinates, clear the average
            userLists[listIndex].averageCoordinate = nil
            userLists[listIndex].lastCoordinateUpdate = Date()
        }
    }
    
    /// Updates the average coordinates in Supabase
    private func updateListAverageCoordinates(userId: String, listId: UUID, averageCoordinate: CLLocationCoordinate2D) async {
        // TODO: Implement with Supabase
        // Previously used Firestore to update place list average coordinates
        // Need to implement equivalent Supabase update
        print("⚠️ updateListAverageCoordinates not yet implemented for Supabase")
    }
    
    /// Sorts userLists by their distance from the user's current location (closest first)
    /// Now uses pre-calculated average coordinates for much faster sorting
    func sortListsByDistance() {
        guard locationManager.currentLocation != nil else { 
            return 
        }
        
        
        userLists.sort { list1, list2 in
            let distance1 = calculateDistanceToList(list1)
            let distance2 = calculateDistanceToList(list2)
            
            // If both lists have valid distances, sort by distance
            if distance1 != Double.infinity && distance2 != Double.infinity {
                return distance1 < distance2
            }
            // If only one has valid distance, prioritize it
            else if distance1 != Double.infinity {
                return true
            }
            else if distance2 != Double.infinity {
                return false
            }
            // If neither has valid distance, sort alphabetically
            else {
                return list1.name < list2.name
            }
        }
        
        hasPerformedInitialSort = true
    }

    /// Public method for manual refresh (if needed) - should only be called by user actions like pull-to-refresh
    func refreshListSorting() {
        sortListsByDistance()
    }
    
    /// Returns whether the initial sort has been performed
    var hasCompletedInitialSort: Bool {
        hasPerformedInitialSort
    }
    
    // MARK: - TikTok Processing
    
    func processSharedTikTokURL(_ urlString: String, 
                               tikTokService: TikTokService,
                               selectedPlaceVM: SelectedPlaceViewModel,
                               placeVM: DetailPlaceViewModel) async -> Bool {
        
        // Check if this URL was recently processed
        if recentlyProcessedURLs.contains(urlString) {
            print("⚠️ [ProfileViewModel] URL already processed recently, skipping: \(urlString)")
            return false
        }
        
        // Check if already processing
        if isProcessingTikTok {
            print("⚠️ [ProfileViewModel] Already processing a TikTok URL, skipping: \(urlString)")
            return false
        }
        
        // Mark as processing and add to recently processed
        await MainActor.run {
            isProcessingTikTok = true
            recentlyProcessedURLs.insert(urlString)
            currentProcessingTikTokUrl = urlString // Store URL for later use
        }
        
        let result = await tikTokService.processTikTokURL(urlString)
        
        // Don't set isProcessingTikTok = false here - let it persist until place detail is ready
        // The loading screen will be dismissed when placeDetailViewReady() is called
        
        // Clear from recently processed after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.recentlyProcessedURLs.remove(urlString)
        }
        
        switch result {
        case .success(let detailPlaces):
            // Clear any previous errors
            tikTokImportError = nil
            
            Task { @MainActor in
                if detailPlaces.count == 1 {
                    // Single place - show detail directly
                    let detailPlace = detailPlaces[0]
                    
                    // Validate place has a name
                    if detailPlace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("❌ [ProfileViewModel] Single place found but has no name")
                        noPlacesFoundTikTokUrl = urlString
                        isShowingNoPlacesFound = true
                        isProcessingTikTok = false
                        deepLinkManager?.isProcessingDeepLink = false
                        return
                    }
                    placeVM.places[detailPlace.id.uuidString] = detailPlace
                    // Add current user as saver so pin shows with profile
                    if let uid = await SupabaseAuthService.shared.currentUserId {
                        placeVM.placeSavers[detailPlace.id.uuidString] = [uid]
                    }
                    placeVM.calculateAnnotationPlaces()
                    selectedPlaceVM.selectPlaceAndFetchDetails(detailPlace, shouldAnimateMap: true)
                    selectedPlaceVM.isDetailSheetPresented = true
                    
                    // Clear loading states immediately
                    isProcessingTikTok = false
                    isWaitingForPlaceDetail = false
                    deepLinkManager?.isProcessingDeepLink = false
                    currentProcessingTikTokUrl = nil
                    
                    refreshTikTokPlacesAfterImport()
                
                } else if detailPlaces.count > 1 {
                    // Multiple places - show selection screen
                    print("🎯 [ProfileViewModel] MULTIPLE PLACES DETECTED: \(detailPlaces.count) places - SHOULD SHOW SELECTION SCREEN")
                    
                    // Validate all places have names
                    let validPlaces = detailPlaces.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    
                    for place in validPlaces {
                        print("   ✓ \(place.name)")
                    }
                    
                    if validPlaces.isEmpty {
                        print("❌ [ProfileViewModel] No valid places found after filtering")
                        noPlacesFoundTikTokUrl = urlString
                        isShowingNoPlacesFound = true
                        isProcessingTikTok = false
                        deepLinkManager?.isProcessingDeepLink = false
                        return
                    }
                    
                    // Add all valid places to place manager
                    for place in validPlaces {
                        placeVM.places[place.id.uuidString] = place
                    }
                    
                    importedPlaces = validPlaces
                    isShowingPlaceSelection = true
                    
                    // Clear loading states
                    isProcessingTikTok = false
                    isWaitingForPlaceDetail = false
                    deepLinkManager?.isProcessingDeepLink = false
                    
                    refreshTikTokPlacesAfterImport()
                } else {
                    // No places found - show flagging interface
                    print("❌ [ProfileViewModel] No places found: count = \(detailPlaces.count)")
                    noPlacesFoundTikTokUrl = urlString
                    isShowingNoPlacesFound = true
                    isProcessingTikTok = false
                    isWaitingForPlaceDetail = false
                    deepLinkManager?.isProcessingDeepLink = false
                }
            }
            
            return true
            
        case .failure(let error):
            print("❌ [ProfileViewModel] TikTok processing failed: \(error.localizedDescription)")
            
            await MainActor.run {
                // Set user-friendly error message based on error type
                if error.localizedDescription.contains("network") || error.localizedDescription.contains("Internet") {
                    tikTokImportError = "Please check your internet connection and try again"
                } else if error.localizedDescription.contains("invalid") || error.localizedDescription.contains("URL") {
                    tikTokImportError = "This doesn't appear to be a valid TikTok URL"
                } else {
                    tikTokImportError = "We couldn't find any places in this TikTok video. Try sharing a different video that shows specific locations"
                }
                isProcessingTikTok = false
                deepLinkManager?.isProcessingDeepLink = false
                currentProcessingTikTokUrl = nil
            }
            
            return false
        }
    }
    
    /// Clear TikTok import error
    func clearTikTokImportError() {
        tikTokImportError = nil
    }
    
    /// Clear place selection state
    func clearPlaceSelection() {
        importedPlaces = []
        isShowingPlaceSelection = false
        currentProcessingTikTokUrl = nil // Clear stored URL
        
        // Refresh TikTok places list after clearing selection (in case places were added to lists)
        refreshTikTokPlacesAfterImport()
    }
    
    /// Clear no places found state
    func clearNoPlacesFound() {
        isShowingNoPlacesFound = false
        noPlacesFoundTikTokUrl = ""
        // Ensure processing states are cleared when user closes the view
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false  // Direct update to ensure sync
    }
    
    func placeSelectionViewAppeared() {
        isWaitingForPlaceDetail = false
        isProcessingTikTok = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false  // Direct update to ensure sync
    }
    
    func ensureListsLoaded() {
        guard let userId = user?.id else { 
            return 
        }
        
        // Check if we need to load places for the first 3 lists
        let firstThreeLists = Array(userLists.prefix(3))
        let needsPlaceLoading = firstThreeLists.contains { list in
            userListsPlaces[list.id.uuidString]?.isEmpty != false
        }
        
        if !needsPlaceLoading {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        
        // Indicate loading state so UI can show a spinner
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        Task {
            do {
                // Use the existing lists (already loaded by DataManager)
                let lists = self.userLists
                
                // Load places and counts for the first 3 visible lists
                let firstThreeListIds = Array(lists.prefix(3).map { $0.id.uuidString })
                
                if !firstThreeListIds.isEmpty {
                    // Fetch places for first 3 lists (6 places each)
                    let placesForLists = try await placeService.fetchPlacesForLists(listIds: firstThreeListIds, maxPlacesPerList: 6)
                    
                    // Fetch place counts for all lists
                    let placeCounts = try await placeService.getPlaceCountsForLists(listIds: lists.map { $0.id.uuidString })
                    
                    await MainActor.run {
                        // Update places for first 3 lists
                        for (listId, places) in placesForLists {
                            let placeIds = places.map { $0.id.uuidString }
                            self.userListsPlaces[listId] = placeIds
                            
                            // Store places in detailPlaceViewModel for immediate access
                            for place in places {
                                self.detailPlaceViewModel.places[place.id.uuidString] = place
                            }
                            
                            // Load images for these places
                            for place in places {
                                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                            }
                            
                            // Mark as loaded
                            if let uuid = UUID(uuidString: listId) {
                                self.loadedListIds.insert(uuid)
                            }
                        }
                        
                        // Store place counts for all lists (for display)
                        for (listId, count) in placeCounts {
                            if let uuid = UUID(uuidString: listId) {
                                self.placeListCounts[uuid] = count
                            }
                        }
                        
                        
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
                
            } catch {
                print("❌ [ProfileViewModel] ensureListsLoaded: Error loading places for lists: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Bulk calculates average coordinates for all lists that don't have them
    /// This is much faster than calculating them one by one
    private func bulkCalculateAverageCoordinates() {
        
        // Group lists by whether they need calculation
        let listsNeedingCalculation = userLists.filter { $0.averageCoordinate == nil }
        let listsWithCoordinates = userLists.filter { $0.averageCoordinate != nil }
        
        
        if listsNeedingCalculation.isEmpty {
            return
        }
        
        // Calculate for all lists that need it
        for list in listsNeedingCalculation {
            recalculateAverageCoordinates(for: list.id)
        }
        
    }
    
    func loadListDataIfNeeded(listId: UUID) {
        guard !loadedListIds.contains(listId) && !loadingListIds.contains(listId),
              let userId = user?.id else {
            return
        }

        // Check if we're at the concurrency limit
        if activeListLoadTasks.count >= maxConcurrentListLoads {
            // Queue the task for later execution
            let task = Task {
                // Wait for a slot to become available
                while activeListLoadTasks.count >= maxConcurrentListLoads {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    if Task.isCancelled { return }
                }
                await self.performListLoad(listId: listId, userId: userId)
            }
            activeListLoadTasks[listId] = task
            return
        }

        // Execute immediately if under the limit
        let task = Task {
            await self.performListLoad(listId: listId, userId: userId)
        }
        activeListLoadTasks[listId] = task
    }

    private func performListLoad(listId: UUID, userId: String) async {
        
        // Check if places are already loaded (e.g., from preloading)
        let alreadyLoaded = await MainActor.run {
            let listIdString = listId.uuidString
            let hasPlaceIds = userListsPlaces[listIdString]?.isEmpty == false
            let hasDetailPlaces = userListsPlaces[listIdString]?.allSatisfy { placeId in
                detailPlaceViewModel.places[placeId] != nil
            } ?? false
            return hasPlaceIds && hasDetailPlaces
        }
        
        if alreadyLoaded {
            await MainActor.run {
                self.loadedListIds.insert(listId)
                self.initializeListPagination(listId: listId)
            }
            return
        }
        
        await MainActor.run {
            self.loadingListIds.insert(listId)
        }

        // Use the optimized method to load places for this list
        do {
            let placesForLists = try await placeService.fetchPlacesForLists(
                listIds: [listId.uuidString], 
                maxPlacesPerList: 50 // Load more places when list is opened
            )
            
            if let places = placesForLists[listId.uuidString] {
                await MainActor.run {
                    let placeIds = places.map { $0.id.uuidString }
                    self.userListsPlaces[listId.uuidString] = placeIds
                    
                    // Store places in detailPlaceViewModel for immediate access
                    for place in places {
                        self.detailPlaceViewModel.places[place.id.uuidString] = place
                    }
                    
                            // Load images for these places
                            for place in places {
                                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                            }
                    
                    self.loadedListIds.insert(listId)
                    self.loadingListIds.remove(listId)
                    self.activeListLoadTasks.removeValue(forKey: listId)

                    // Initialize pagination for this list
                    self.initializeListPagination(listId: listId)
                }
            }
        } catch {
            print("❌ [ProfileViewModel] performListLoad: Error loading places for list \(listId): \(error)")
            await MainActor.run {
                self.loadingListIds.remove(listId)
                self.activeListLoadTasks.removeValue(forKey: listId)
            }
        }
    }
    
    /// Load more lists when user scrolls (lazy loading)
    func loadMoreListsIfNeeded() {
        // Find the next 3 lists that haven't been loaded yet
        let unloadedLists = userLists.filter { !loadedListIds.contains($0.id) && !loadingListIds.contains($0.id) }
        let nextThreeLists = Array(unloadedLists.prefix(3))
        
        guard !nextThreeLists.isEmpty else { return }
        
        let listIds = nextThreeLists.map { $0.id.uuidString }
        
        Task {
            do {
                // Mark as loading
                await MainActor.run {
                    for list in nextThreeLists {
                        self.loadingListIds.insert(list.id)
                    }
                }
                
                // Fetch places for these lists
                let placesForLists = try await placeService.fetchPlacesForLists(listIds: listIds, maxPlacesPerList: 6)
                
                await MainActor.run {
                    // Update places for these lists
                    for (listId, places) in placesForLists {
                        let placeIds = places.map { $0.id.uuidString }
                        self.userListsPlaces[listId] = placeIds
                        
                        // Store places in detailPlaceViewModel for immediate access
                        for place in places {
                            self.detailPlaceViewModel.places[place.id.uuidString] = place
                        }
                        
                            // Load images for these places
                            for place in places {
                                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                            }
                        
                        // Mark as loaded
                        if let uuid = UUID(uuidString: listId) {
                            self.loadedListIds.insert(uuid)
                            self.loadingListIds.remove(uuid)
                        }
                    }
                    
                }
            } catch {
                print("❌ [ProfileViewModel] loadMoreListsIfNeeded: Error loading more lists: \(error)")
                await MainActor.run {
                    for list in nextThreeLists {
                        self.loadingListIds.remove(list.id)
                    }
                }
            }
        }
    }
    
    // MARK: - List Place Pagination Methods
    
    /// Initialize pagination state for a list
    private func initializeListPagination(listId: UUID) {
        let listIdString = listId.uuidString
        guard let allPlaceIds = userListsPlaces[listIdString], !allPlaceIds.isEmpty else {
            return
        }
        
        // Initialize pagination state
        var pagination = ListPlacePagination()
        pagination.allPlaceIds = allPlaceIds
        pagination.hasMorePlaces = allPlaceIds.count > pagination.placesPerPage
        
        // Store initial pagination before loading the first page
        listPlacePagination[listIdString] = pagination
        
        // Load first page
        loadNextPageForList(listId: listId)
        
        // Trigger image preloading for initial places
        preloadImagesForVisiblePlaces(listId: listId)
    }
    
    /// Public method to initialize pagination if needed (called from views)
    func initializeListPaginationIfNeeded(listId: UUID) {
        let listIdString = listId.uuidString
        let allPlaceIds = userListsPlaces[listIdString] ?? []
        
        // Only initialize if not already initialized
        if listPlacePagination[listIdString] == nil {
            initializeListPagination(listId: listId)
        } else {
        }
    }
    
    /// Load the next page of places for a specific list
    func loadNextPageForList(listId: UUID) {
        let listIdString = listId.uuidString
        guard var pagination = listPlacePagination[listIdString],
              !pagination.isLoadingMore,
              pagination.hasMorePlaces else {
            return
        }
        
        pagination.isLoadingMore = true
        listPlacePagination[listIdString] = pagination
        
        let startIndex = pagination.currentPage * pagination.placesPerPage
        let endIndex = min(startIndex + pagination.placesPerPage, pagination.allPlaceIds.count)
        
        guard startIndex < pagination.allPlaceIds.count else {
            pagination.isLoadingMore = false
            pagination.hasMorePlaces = false
            listPlacePagination[listIdString] = pagination
            return
        }
        
        let placeIdsToLoad = Array(pagination.allPlaceIds[startIndex..<endIndex])
        
        Task {
            // Load place details for the new place IDs
            for placeId in placeIdsToLoad {
                if detailPlaceViewModel.places[placeId] == nil {
                    do {
                        let detailPlace = try await placeService.fetchPlace(withId: placeId)
                        detailPlaceViewModel.places[placeId] = detailPlace
                        detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    } catch {
                        print("❌ [ProfileViewModel] loadNextPageForList: Failed to load place \(placeId): \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                // Update pagination state
                if var updatedPagination = self.listPlacePagination[listIdString] {
                    updatedPagination.loadedPlaceIds.append(contentsOf: placeIdsToLoad)
                    updatedPagination.currentPage += 1
                    updatedPagination.isLoadingMore = false
                    updatedPagination.hasMorePlaces = endIndex < updatedPagination.allPlaceIds.count
                    
                    self.listPlacePagination[listIdString] = updatedPagination
                    
                    // Trigger image preloading for newly loaded places
                    self.preloadImagesForVisiblePlaces(listId: listId)
                }
            }
        }
    }
    
    /// Get the displayed place IDs for a list (respecting pagination)
    func getDisplayedPlaceIds(for listId: UUID) -> [String] {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.displayedPlaceIds ?? []
    }
    
    /// Check if a list has more places to load
    func hasMorePlaces(for listId: UUID) -> Bool {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.hasMorePlaces ?? false
    }
    
    /// Check if a list is currently loading more places
    func isLoadingMorePlaces(for listId: UUID) -> Bool {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.isLoadingMore ?? false
    }
    
    /// Get the total number of places in a list
    func getTotalPlaceCount(for listId: UUID) -> Int {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.totalPlaces ?? 0
    }
    
    /// Reset pagination for a list (call when places are added/removed)
    func resetListPagination(listId: UUID) {
        let listIdString = listId.uuidString
        listPlacePagination.removeValue(forKey: listIdString)
        
        // Re-initialize pagination if the list has places
        if let placeIds = userListsPlaces[listIdString], !placeIds.isEmpty {
            initializeListPagination(listId: listId)
        }
    }
    
    // MARK: - Place List Pagination (for lists themselves, not places within lists)
    
    /// Check if we should load more place lists based on current scroll position
    func shouldLoadMorePlaceLists(currentItem: LightweightPlaceList, filteredLists: [LightweightPlaceList], isSearching: Bool) -> Bool {
        // Don't load during search
        guard !isSearching else { return false }
        
        // Check loading state and availability
        guard !isLoadingMorePlaceLists && hasMorePlaceLists else { return false }
        
        // Calculate threshold (3 items from the end)
        let threshold = max(0, filteredLists.count - 3)
        
        // Find current item's index
        guard let currentIndex = filteredLists.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        
        // Load more when at or past threshold
        return currentIndex >= threshold
    }
    
    /// Append new place lists with deduplication
    /// Single Responsibility: ViewModel owns state management including deduplication
    /// - Parameters:
    ///   - newLists: Lists fetched from the service
    ///   - nextPage: The page number these lists came from
    ///   - pageSize: Number of items per page (for determining if more exist)
    func appendPlaceLists(_ newLists: [LightweightPlaceList], nextPage: Int, pageSize: Int) {
        // Guard: Nothing to append
        guard !newLists.isEmpty else {
            hasMorePlaceLists = false
            return
        }
        
        // Deduplication - ViewModel owns this logic because it owns the state
        let existingIds = Set(lightweightPlaceLists.map { $0.list_id })
        let uniqueNewLists = newLists.filter { !existingIds.contains($0.list_id) }
        
        // Log duplicates for debugging
        let duplicateCount = newLists.count - uniqueNewLists.count
        if duplicateCount > 0 {
            print("⚠️ [ProfileViewModel] Filtered \(duplicateCount) duplicate place lists")
        }
        
        // Update state with unique lists
        if !uniqueNewLists.isEmpty {
            lightweightPlaceLists.append(contentsOf: uniqueNewLists)
            placeListsCurrentPage = nextPage
            
            // Update counts for new lists
            for list in uniqueNewLists {
                if lightweightPlaceListCounts[list.list_id] == nil {
                    lightweightPlaceListCounts[list.list_id] = list.place_count
                }
            }
            
        } else {
            print("⚠️ [ProfileViewModel] All \(newLists.count) lists were duplicates - potential pagination issue")
        }
        
        // Update pagination flag based on fetched count (not unique count)
        hasMorePlaceLists = newLists.count >= pageSize
    }
    
    // MARK: - Place List Places State Management
    
    /// Append new places to a list with deduplication
    /// Single Responsibility: ViewModel owns state management including deduplication
    /// - Parameters:
    ///   - listId: The list to append places to
    ///   - newPlaces: Places fetched from the service
    func appendPlacesForList(listId: String, newPlaces: [LightweightPlace]) {
        guard !newPlaces.isEmpty else { return }
        
        // Get existing places or empty array
        let existingPlaces = lightweightPlaceListPlaces[listId] ?? []
        
        // Deduplication - ViewModel owns this logic because it owns the state
        let existingIds = Set(existingPlaces.map { $0.place_id })
        let uniqueNewPlaces = newPlaces.filter { !existingIds.contains($0.place_id) }
        
        // Log duplicates for debugging
        let duplicateCount = newPlaces.count - uniqueNewPlaces.count
        if duplicateCount > 0 {
            print("⚠️ [ProfileViewModel] Filtered \(duplicateCount) duplicate places for list \(listId)")
        }
        
        // Update state with unique places
        if !uniqueNewPlaces.isEmpty {
            lightweightPlaceListPlaces[listId] = existingPlaces + uniqueNewPlaces
        }
    }
    
    /// Set places for a list with deduplication (for initial load)
    /// Single Responsibility: ViewModel owns state management including deduplication
    /// - Parameters:
    ///   - listId: The list to set places for
    ///   - places: Places fetched from the service
    func setPlacesForList(listId: String, places: [LightweightPlace]) {
        // Deduplicate by place_id (keep first occurrence)
        var seenIds = Set<String>()
        let uniquePlaces = places.filter { place in
            if seenIds.contains(place.place_id) {
                return false
            }
            seenIds.insert(place.place_id)
            return true
        }
        
        let duplicateCount = places.count - uniquePlaces.count
        if duplicateCount > 0 {
            print("⚠️ [ProfileViewModel] Filtered \(duplicateCount) duplicate places for list \(listId)")
        }
        
        lightweightPlaceListPlaces[listId] = uniquePlaces
    }
    
    /// Smart image preloading for visible places (simplified)
    func preloadImagesForVisiblePlaces(listId: UUID) {
        let displayedPlaceIds = getDisplayedPlaceIds(for: listId)
        
        // Simple preloading without complex async - just mark as ready
        for placeId in displayedPlaceIds {
            if let place = detailPlaceViewModel.places[placeId] {
                // Preload TikTok thumbnails
                if let tikTokVideos = place.tikTokVideos,
                   let firstVideo = tikTokVideos.first,
                   !firstVideo.thumbnailURL.isEmpty {
                    preloadedImages[firstVideo.thumbnailURL] = true
                }
                
                // Note: DetailPlace doesn't have reviews property, so skipping review image preloading
            }
        }
    }
    
    private func handleMultiplePlaces(_ places: [DetailPlace]) {
        print("🎯 [ProfileViewModel] Received \(places.count) places from DeepLinkManager")
        for place in places {
            print("   - \(place.name) (ID: \(place.id))")
        }
        
        importedPlaces = places
        isShowingPlaceSelection = true
        // Keep isWaitingForPlaceDetail = true until the sheet actually appears
        
        print("🎯 [ProfileViewModel] Set isShowingPlaceSelection = true")
    }
    
    /// Handle multiple places notification from DeepLinkManager
    /// This is called when a notification is received with multiple places and TikTok URL
    func handleMultiplePlacesNotification(places: [DetailPlace], tikTokUrl: String?) {
        print("🎯 [ProfileViewModel] Handling multiple places notification with TikTok URL")
        if let tikTokUrl = tikTokUrl {
            currentProcessingTikTokUrl = tikTokUrl
        }
        handleMultiplePlaces(places)
    }
    

    
    // MARK: - Place Conversion
    
    func convertToDetailPlace(_ nearbyPlace: NearbyPlaceFeature) -> DetailPlace {
        var detailPlace = DetailPlace()
        detailPlace.id = createConsistentUUID(from: nearbyPlace.properties.actualId)
        detailPlace.name = nearbyPlace.properties.name
        detailPlace.address = nearbyPlace.properties.address
        detailPlace.coordinate = CLLocationCoordinate2D(
            latitude: nearbyPlace.geometry.latitude,
            longitude: nearbyPlace.geometry.longitude
        )
        detailPlace.rating = nearbyPlace.properties.rating
        detailPlace.categories = nearbyPlace.properties.types
        detailPlace.phone = nearbyPlace.properties.photoReference
        return detailPlace
    }
    
    private func createConsistentUUID(from string: String) -> UUID {
        if let uuid = UUID(uuidString: string) {
            return uuid
        }
        
        let hash = abs(string.hashValue)
        let uuidString = String(format: "%08x-0000-0000-0000-%012x", hash, hash)
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    // MARK: - User Actions
    
    func logout() {
        userSession.logout()
    }
    
    // MARK: - Logout Cleanup
    
    /// Clears all user-related cached data - MUST be called on logout to prevent data leakage
    /// Single Responsibility: Only clears this ViewModel's cached state
    func clearAllUserData() {
        print("🗑️ [ProfileViewModel] Clearing all user data for security")
        
        // Clear user profile data
        user = nil
        userPicture = nil
        
        // Clear TikTok/external places data
        lightweightExternalPlaces.removeAll()
        totalExternalPlacesCount = 0
        userExternalPlaces.removeAll()
        allTikTokPlaceIds.removeAll()
        loadedTikTokPlaceIds.removeAll()
        currentTikTokPage = 0
        recentlyProcessedURLs.removeAll()
        _hasMoreTikTokPlaces = true
        
        // Clear reviewed places data
        lightweightReviewedPlaces.removeAll()
        totalReviewedPlacesCount = 0
        hasAttemptedInitialReviewsLoad = false
        
        // Clear user lists and places
        userLists.removeAll()
        userListsPlaces.removeAll()
        lightweightPlaceLists.removeAll()
        lightweightPlaceListPlaces.removeAll()
        lightweightPlaceListCounts.removeAll()
        placeListCounts.removeAll()
        listPlacePagination.removeAll()
        loadedListIds.removeAll()
        loadingListIds.removeAll()
        activeListLoadTasks.values.forEach { $0.cancel() }
        activeListLoadTasks.removeAll()
        placeListsCurrentPage = 1
        
        // Clear favorites
        userFavorites.removeAll()
        lightweightFavorites.removeAll()
        lightweightMyPlaces.removeAll()
        myPlaces.removeAll()
        totalMyPlacesCount = 0
        
        // Clear social data
        userFollowing.removeAll()
        userFollowers.removeAll()
        followersCount = 0
        followingCount = 0
        
        // Clear place notes and flags
        placeNotes.removeAll()
        tikTokPlaceFlags.removeAll()
        
        // Clear TikTok processing state
        importedPlaces.removeAll()
        currentProcessingTikTokUrl = nil
        noPlacesFoundTikTokUrl = ""
        
        // Reset loading states
        isLoadingReviewedPlaces = false
        isLoadingMoreReviews = false
        hasMoreReviews = true
        isLoadingTikTokPlaces = false
        isLoadingMoreExternalPlaces = false
        hasMoreExternalPlaces = true
        isLoadingMoreMyPlaces = false
        hasMoreMyPlaces = true
        isLoadingInitialLists = false
        isLoadingMorePlaceLists = false
        hasMorePlaceLists = true
        isLoadingMoreTikTokPlaces = false
        isMyPlacesLoading = true
        isFollowersLoading = true
        isFollowingLoading = true
        isFollowersListLoading = false
        isFollowingListLoading = false
        hasMoreFollowers = true
        hasMoreFollowing = true
        
        // Clear other state
        preloadedImages.removeAll()
        recentlyCreatedListId = nil
        listCreationTime = nil
        totalListCount = 0
        totalUniquePlacesCount = 0
        showOnlySharedLists = false
        hasPerformedInitialSort = false
        
        // Clear UI state flags
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        isShowingPlaceSelection = false
        isShowingNoPlacesFound = false
        tikTokImportError = nil
        showMaxFavoritesAlert = false
        isUploadingProfilePhoto = false
        showFollowError = false
        followErrorMessage = ""
        
        print("✅ [ProfileViewModel] All user data cleared")
    }
    
    func handleTikTokNotification(url: String, 
                                 tikTokService: TikTokService,
                                 selectedPlaceVM: SelectedPlaceViewModel,
                                 placeVM: DetailPlaceViewModel) {
        Task {
            await processSharedTikTokURL(url, 
                                       tikTokService: tikTokService,
                                       selectedPlaceVM: selectedPlaceVM,
                                       placeVM: placeVM)
        }
    }
    
    func checkPendingTikTokURL(tikTokService: TikTokService,
                              selectedPlaceVM: SelectedPlaceViewModel,
                              placeVM: DetailPlaceViewModel) {
        if let pendingURL = UserDefaults.standard.string(forKey: "pendingTikTokURL") {
            Task {
                await processSharedTikTokURL(pendingURL,
                                           tikTokService: tikTokService,
                                           selectedPlaceVM: selectedPlaceVM,
                                           placeVM: placeVM)
            }
            UserDefaults.standard.removeObject(forKey: "pendingTikTokURL")
        }
    }
    
    /// Formats distance for display (meters to miles/kilometers)
    private func formatDistance(_ distanceInMeters: Double) -> String {
        if distanceInMeters == Double.infinity {
            return "Unknown"
        }
        
        let miles = distanceInMeters * 0.000621371 // Convert meters to miles
        if miles < 1 {
            let feet = distanceInMeters * 3.28084 // Convert meters to feet
            return String(format: "%.0f ft", feet)
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
    
    /// Returns the formatted average distance for a list
    func getAverageDistanceForList(_ list: PlaceList) -> String {
        let distance = calculateDistanceToList(list)
        return formatDistance(distance)
    }

    /// Returns true if location is available for distance calculations
    var isLocationAvailable: Bool {
        return locationManager.currentLocation != nil
    }
    
    // MARK: - Place-Specific List Sorting
    
    /// Calculates the average distance of all places in a list from a specific place
    /// FAST VERSION: Uses pre-calculated average coordinates when available
    func calculateAverageDistanceForListFromPlace(_ list: PlaceList, place: DetailPlace) -> Double {
        guard let placeCoordinate = place.coordinate else { 
            print("⚠️ [ProfileViewModel] Place '\(place.name)' has no coordinate, returning infinity")
            return Double.infinity 
        }
        
        // FAST PATH: Use pre-calculated average coordinates if available (much faster!)
        if let averageCoordinate = list.averageCoordinate {
            let targetLocation = CLLocation(
                latitude: placeCoordinate.latitude,
                longitude: placeCoordinate.longitude
            )
            let listLocation = CLLocation(
                latitude: averageCoordinate.latitude,
                longitude: averageCoordinate.longitude
            )
            
            let distance = targetLocation.distance(from: listLocation)
            return distance
        }
        
        // SLOW PATH: Fallback to calculating from individual places (only if no average coordinate)
        let listPlaceIds = userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { 
            print("⚠️ [ProfileViewModel] List '\(list.name)' has no places, returning infinity")
            return Double.infinity 
        }
        
        print("🐌 [ProfileViewModel] SLOW: Calculating distance for list '\(list.name)' with \(listPlaceIds.count) places (no average coordinate)")
        
        let targetLocation = CLLocation(
            latitude: placeCoordinate.latitude,
            longitude: placeCoordinate.longitude
        )
        
        var totalDistance: Double = 0
        var validPlaceCount: Int = 0
        
        for placeId in listPlaceIds {
            if let detailPlace = detailPlaceViewModel.places[placeId],
               let listPlaceCoordinate = detailPlace.coordinate {
                
                let listPlaceLocation = CLLocation(
                    latitude: listPlaceCoordinate.latitude,
                    longitude: listPlaceCoordinate.longitude
                )
                
                let distance = targetLocation.distance(from: listPlaceLocation)
                totalDistance += distance
                validPlaceCount += 1
                
            } else {
                print("⚠️ [ProfileViewModel] Could not find place with ID \(placeId) or it has no coordinate")
            }
        }
        
        let averageDistance = validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
        print("🐌 [ProfileViewModel] SLOW: List '\(list.name)' average distance: \(averageDistance == Double.infinity ? "infinity" : String(format: "%.1f km", averageDistance/1000)) (valid places: \(validPlaceCount)/\(listPlaceIds.count))")
        
        return averageDistance
    }
    
    /// Sorts lists by their proximity to a specific place (closest first)
    func sortListsByDistanceFromPlace(_ place: DetailPlace) -> [PlaceList] {
        return userLists.sorted { list1, list2 in
            let distance1 = calculateAverageDistanceForListFromPlace(list1, place: place)
            let distance2 = calculateAverageDistanceForListFromPlace(list2, place: place)
            return distance1 < distance2
        }
    }
    
    /// Helper to check if a list is "recently" created (within last 60 seconds)
    func isListRecentlyCreated(_ listId: UUID) -> Bool {
        guard let createdId = recentlyCreatedListId,
              let creationTime = listCreationTime,
              createdId == listId else {
            return false
        }
        
        // Only consider "recent" if created within last 60 seconds
        return Date().timeIntervalSince(creationTime) < 60
    }
    
    /// Set the recently created list ID with timestamp
    func setRecentlyCreatedList(_ listId: UUID) {
        recentlyCreatedListId = listId
        listCreationTime = Date()
    }
    
    /// Clear the recently created list flag (called on user interaction)
    func clearRecentlyCreatedList() {
        recentlyCreatedListId = nil
        listCreationTime = nil
    }
    
    /// Sorts lists with recently created list at the top, then by proximity to a specific place
    func sortListsWithRecentFirstFromPlace(_ place: DetailPlace) -> [PlaceList] {
        return userLists.sorted { list1, list2 in
            // If one of the lists is recently created (and still within time window), prioritize it
            if isListRecentlyCreated(list1.id) {
                return true
            }
            if isListRecentlyCreated(list2.id) {
                return false
            }
            
            // Otherwise, sort by distance
            let distance1 = calculateAverageDistanceForListFromPlace(list1, place: place)
            let distance2 = calculateAverageDistanceForListFromPlace(list2, place: place)
            return distance1 < distance2
        }
    }
    
    // MARK: - External Places (TikTok-sourced places) - OLD CODE, KEEP FOR TikTok deletion
    
    /// OLD: This function is no longer used for loading - we use lightweight loading now
    /// KEEP: Still needed for TikTok place deletion to work with userExternalPlaces dictionary
    /// Note: This populates the dictionary for quick lookups, but getTikTokVideos() queries directly for accuracy
    func fetchUserExternalPlaces() async {
        guard let userId = user?.id else { 
            print("❌ [ProfileViewModel] No user ID available for fetching external places")
            return 
        }
        
        do {
            let externalPlaces = try await userService.fetchAllUserExternalPlaces(userId: userId)
            
            // Convert array to dictionary (note: if multiple external places exist for same placeId,
            // only the last one will be stored - this is okay for quick lookups)
            let externalPlacesDict = Dictionary(uniqueKeysWithValues: externalPlaces.map { ($0.placeId, $0) })
            
            // Update on main thread
            await MainActor.run {
                self.userExternalPlaces = externalPlacesDict
            }
            
            // Prefetch TikTok metadata for external places
            let urls = externalPlaces.compactMap { $0.url }.filter { !$0.isEmpty }
            await TikTokMetadataCache.shared.prefetchMetadata(for: urls)
            
            // Load thumbnails after metadata is fetched
            await MainActor.run {
                for externalPlace in externalPlaces {
                    if let url = externalPlace.url,
                       let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: url) {
                        Task {
                            await self.loadTikTokThumbnailAsPlaceImage(
                            placeId: externalPlace.placeId,
                            thumbnailURL: thumbnailURL
                        )
                        }
                    }
                }
            }
        } catch {
            print("❌ [ProfileViewModel] Error fetching external places: \(error.localizedDescription)")
        }
    }
    
    func ensureTikTokThumbnailCached(for placeId: String) {
        if detailPlaceViewModel.placeImages[placeId] != nil {
            return
        }
        
        Task { [weak self] in
            await self?.fetchFallbackImages(for: [placeId])
        }
    }
    
    func fetchFallbackImages(for placeIds: [String]) async {
        var remaining = placeIds.filter { detailPlaceViewModel.placeImages[$0] == nil }
        guard !remaining.isEmpty else { return }
        
        if let userId = user?.id {
            do {
                let urlMap = try await SupabaseUserService.shared.fetchExternalPlaceURLs(placeIds: Array(remaining), userId: userId)
                
                for placeId in remaining {
                    guard let url = urlMap[placeId], !url.isEmpty else { continue }
                    guard detailPlaceViewModel.placeImages[placeId] == nil else { continue }
                    
                    guard let video = await TikTokMetadataCache.shared.getMetadata(for: url) else { continue }
                    let thumbnailURL = video.thumbnailURL
                    guard !thumbnailURL.isEmpty else { continue }
                    
                    loadRemoteImageAsPlaceImage(placeId: placeId, imageURL: thumbnailURL)
                }
            } catch {
                print("❌ [ProfileViewModel] Error fetching TikTok thumbnails: \(error.localizedDescription)")
            }
            
            remaining = remaining.filter { detailPlaceViewModel.placeImages[$0] == nil }
        }
        
        guard !remaining.isEmpty else { return }
        
        // Try regular user reviews first (from reviews table)
        do {
            let regularReviewImages = try await SupabaseUserService.shared.fetchRegularReviewImages(for: Array(remaining))
            for (placeId, imageUrl) in regularReviewImages {
                guard detailPlaceViewModel.placeImages[placeId] == nil else { continue }
                loadRemoteImageAsPlaceImage(placeId: placeId, imageURL: imageUrl)
            }
        } catch {
            print("❌ [ProfileViewModel] Error fetching regular review images: \(error.localizedDescription)")
        }
        
        remaining = remaining.filter { detailPlaceViewModel.placeImages[$0] == nil }
        guard !remaining.isEmpty else { return }
        
        // Finally try external reviews (from external_reviews table - Google, etc.)
        do {
            let externalReviewImages = try await SupabaseUserService.shared.fetchExternalReviewImages(for: Array(remaining))
            for (placeId, imageUrl) in externalReviewImages {
                guard detailPlaceViewModel.placeImages[placeId] == nil else { continue }
                loadRemoteImageAsPlaceImage(placeId: placeId, imageURL: imageUrl)
            }
        } catch {
            print("❌ [ProfileViewModel] Error fetching external review images: \(error.localizedDescription)")
        }
    }
    
    private func loadRemoteImageAsPlaceImage(placeId: String, imageURL: String) {
        if detailPlaceViewModel.placeImages[placeId] != nil {
            return
        }
        
        guard let url = URL(string: imageURL) else {
            print("❌ [ProfileViewModel] Invalid image URL for place \(placeId): \(imageURL)")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileViewModel] Error loading image for \(placeId): \(error.localizedDescription)")
                } else if let data = data, let image = UIImage(data: data) {
                    self.detailPlaceViewModel.placeImages[placeId] = image
                } else {
                    print("⚠️ [ProfileViewModel] No image data returned for place \(placeId)")
                }
            }
        }.resume()
    }
    
    /// Get TikTok videos for a specific place ID (async)
    /// Fetches all external_places for the place and returns TikTok videos with metadata
    /// Fetch TikTok videos from ALL users for a place
    /// Populates ownership data for proper deletion and UI display
    func getTikTokVideos(for placeId: String) async -> [TikTokVideo] {
        do {
            // Fetch TikTok URLs from ALL users (not just current user)
            let urlTuples = try await userService.fetchAllExternalPlaceURLs(placeId: placeId)
            
            // Fetch metadata for each URL and populate ownership
            var tikTokVideos: [TikTokVideo] = []
            for tuple in urlTuples {
                if var tikTokVideo = await TikTokMetadataCache.shared.getMetadata(for: tuple.url) {
                    // Populate ownership tracking for deletion/display
                    tikTokVideo.savedByUserId = tuple.userId
                    tikTokVideo.externalPlaceId = tuple.id
                    tikTokVideos.append(tikTokVideo)
                }
            }
            
            return tikTokVideos
        } catch {
            print("❌ [ProfileViewModel] Error fetching TikTok videos for place \(placeId): \(error)")
            return []
        }
    }
    
    /// Get external_place_id for a TikTok video URL at a specific place
    func getExternalPlaceId(for placeId: String, videoUrl: String) async -> String? {
        guard let userId = user?.id else {
            return nil
        }
        
        do {
            let urlPairs = try await userService.fetchExternalPlaceURLs(placeId: placeId, userId: userId)
            return urlPairs.first(where: { $0.url == videoUrl })?.id
        } catch {
            print("❌ [ProfileViewModel] Error fetching external_place_id: \(error)")
            return nil
        }
    }
    
    /// Check if user has TikTok videos for a specific place
    /// Note: This is a quick check using cached data. For accurate results, use getTikTokVideos() instead.
    func hasTikTokVideos(for placeId: String) -> Bool {
        // Check if any external place exists for this place in the cached dictionary
        return userExternalPlaces.values.contains { $0.placeId == placeId && $0.url != nil && !$0.url!.isEmpty }
    }
    
    /// Get the external place data for a specific place ID
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return userExternalPlaces[placeId]
    }
    
    /// Get first TikTok thumbnail URL for a place (synchronous, uses cache only)
    func getFirstTikTokThumbnailURL(for placeId: String) -> String? {
        guard let externalPlace = userExternalPlaces[placeId],
              let url = externalPlace.url else {
            return nil
        }
        return TikTokMetadataCache.shared.getCachedThumbnailUrl(for: url)
    }

    func loadPlaceImageWithFallback(for place: DetailPlace) {
        let placeId = place.id.uuidString
        
        // If image already exists, no need to do anything
        if detailPlaceViewModel.placeImages[placeId] != nil {
            return
        }
        
        // If there's no review image, try to load a TikTok thumbnail
        Task {
            if let externalPlace = getExternalPlace(for: placeId),
               let url = externalPlace.url,
               let thumbnailURL = await TikTokMetadataCache.shared.getThumbnailUrl(for: url) {
                
                // Load TikTok thumbnail directly
                await loadTikTokThumbnailAsPlaceImage(placeId: placeId, thumbnailURL: thumbnailURL)
            }
        }
    }
    
    /// Load TikTok thumbnail as place image for external places
    private func loadTikTokThumbnailAsPlaceImage(placeId: String, thumbnailURL: String) async {
        guard let url = URL(string: thumbnailURL) else {
            print("❌ [ProfileViewModel] Invalid thumbnail URL for place \(placeId): \(thumbnailURL)")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.detailPlaceViewModel.placeImages[placeId] = image
                    }
            } else {
                print("⚠️ [ProfileViewModel] No image data returned for TikTok thumbnail \(placeId)")
            }
        } catch {
            print("❌ [ProfileViewModel] Error loading TikTok thumbnail for \(placeId): \(error.localizedDescription)")
        }
    }
    
    /// Load images for places with prioritization - first 8 immediately, rest in background
    func loadPriorityImagesForPlaces(_ places: [DetailPlace], priorityCount: Int = 8) {
        let priorityPlaces = Array(places.prefix(priorityCount))
        let remainingPlaces = Array(places.dropFirst(priorityCount))
        
        // Load priority places immediately
        for place in priorityPlaces {
            detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
        }
        
        // Load remaining places in background with lower priority
        if !remainingPlaces.isEmpty {
            Task.detached(priority: .background) { [weak self] in
                // Add small delay to not interfere with priority loading
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                for place in remainingPlaces {
                    await MainActor.run {
                        self?.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                    }
                    // Small delay between each background load to avoid overwhelming the system
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
        }
    }

    func deleteMyPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        guard let userId = user?.id else {
            completion(false)
            return
        }

        let placeId = place.id.uuidString
        
        // Optimistically remove from local array
        myPlaces.removeAll { $0 == placeId }
        
        // Remove from map annotations immediately (optimistic update)
        detailPlaceViewModel.places.removeValue(forKey: placeId)
        
        // Remove from placeSavers (so it doesn't appear on map)
        if var savers = detailPlaceViewModel.placeSavers[placeId] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            } else {
                detailPlaceViewModel.placeSavers[placeId] = savers
            }
        }
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Send notification to refresh map annotations
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)

        // Asynchronously delete from backend
        Task {
            var myPlacesDeleteSuccess = false
            var allPlacesDeleteSuccess = false
            
            // Delete from my_places
            placeService.deletePlaceFromMyPlaces(userId: userId, placeId: placeId) { error in
                if let error = error {
                    print("❌ Error deleting place from my places: \(error)")
                } else {
                    myPlacesDeleteSuccess = true
                }
            }
            
            // Delete from all_places (only for custom places)
            placeService.deletePlaceFromAllPlaces(placeId: placeId) { error in
                if let error = error {
                    print("❌ Error deleting place from all places: \(error)")
                } else {
                    allPlacesDeleteSuccess = true
                }
            }
            
            // Wait a moment for both operations to complete
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // On success, call completion on main thread
            await MainActor.run {
                if myPlacesDeleteSuccess {
                    completion(true)
                } else {
                    // If deletion fails, revert the optimistic updates
                    print("❌ [ProfileViewModel] Failed to delete custom place, reverting changes")
                    myPlaces.append(placeId)
                    detailPlaceViewModel.places[placeId] = place
                    
                    // Re-add to placeSavers
                    if detailPlaceViewModel.placeSavers[placeId] == nil {
                        detailPlaceViewModel.placeSavers[placeId] = [userId]
                    } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                        detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                    }
                    
                    // Recalculate map annotations
                    detailPlaceViewModel.calculateAnnotationPlaces()
                    
                    // Send notification to refresh map annotations
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
                    
                    completion(false)
                }
            }
        }
    }
    
    /// Delete a place created by the user (LightweightPlace version for PopupPlaceCard)
    /// Handles optimistic updates and backend deletion
    func deleteMyPlace(_ place: LightweightPlace) {
        guard let userId = user?.id else { return }
        
        let placeId = place.place_id
        
        // Optimistic update: Remove from all local collections immediately
        removeFromLocalMyPlacesState(placeId: placeId, userId: userId)
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Send notification to refresh map annotations
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
        
        // Persist deletion to backend
        Task {
            // Delete from my_places
            placeService.deletePlaceFromMyPlaces(userId: userId, placeId: placeId) { error in
                if let error = error {
                    print("❌ [ProfileViewModel] Error deleting place from my_places: \(error.localizedDescription)")
                }
            }
            
            // Delete from all_places (only for custom places)
            placeService.deletePlaceFromAllPlaces(placeId: placeId) { error in
                if let error = error {
                    print("❌ [ProfileViewModel] Error deleting place from all_places: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Helper: Remove my place from all local state collections
    /// Single Responsibility: Local state cleanup only
    private func removeFromLocalMyPlacesState(placeId: String, userId: String) {
        // Remove from lightweight places array
        lightweightMyPlaces.removeAll { $0.place_id == placeId }
        
        // Remove from ID tracking collection
        myPlaces.removeAll { $0 == placeId }
        
        // Update total count
        if totalMyPlacesCount > 0 {
            totalMyPlacesCount -= 1
        }
        
        // Remove from map annotations
        detailPlaceViewModel.places.removeValue(forKey: placeId)
        
        // Remove from placeSavers (so it doesn't appear on map)
        if var savers = detailPlaceViewModel.placeSavers[placeId] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            } else {
                detailPlaceViewModel.placeSavers[placeId] = savers
            }
        }
    }
    
    // MARK: - Account Deletion
    
    /// Show initial delete account warning (Step 1 of 2)
    func showDeleteWarning() {
        showDeleteAccountWarning = true
    }
    
    /// Proceed to final confirmation (Step 2 of 2)
    func proceedToFinalConfirmation() {
        showDeleteAccountWarning = false
        showDeleteAccountConfirmation = true
    }
    
    /// Cancel delete account flow
    func cancelDeleteAccount() {
        showDeleteAccountWarning = false
        showDeleteAccountConfirmation = false
        deleteAccountError = nil
    }
    
    /// Initiate account deletion with UI state management
    /// Staff Engineer: Single entry point for delete account execution
    func initiateAccountDeletion() {
        isDeletingAccount = true
        deleteAccountError = nil
        
        deleteAccount { [weak self] success, errorMessage in
            guard let self = self else { return }
            
            self.isDeletingAccount = false
            
            if success {
                self.showDeleteAccountConfirmation = false
            } else {
                self.deleteAccountError = errorMessage ?? "Failed to delete account. Please try again."
            }
        }
    }
    
    /// Clear delete account error state
    func clearDeleteAccountError() {
        deleteAccountError = nil
    }
    
    /// Delete user account and all associated data
    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let userId = user?.id else {
            completion(false, "No user ID found")
            return
        }
        
        // Delete user data from Firestore
        userService.deleteUserAccount(userId: userId) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileViewModel] Error deleting account: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else {
                    // Delete Supabase Auth user
                    Task { @MainActor in
                        do {
                            try await SupabaseAuthService.shared.deleteAccount()
                            
                            // Log out the user
                            self?.userSession.logout()
                            
                            completion(true, nil)
                        } catch {
                            print("❌ [ProfileViewModel] Error deleting Supabase Auth user: \(error.localizedDescription)")
                            completion(false, "Failed to delete authentication account: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

