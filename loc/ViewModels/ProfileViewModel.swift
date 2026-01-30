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

    // MARK: - Lists Properties (Proxies to listsViewModel for backwards compatibility)

    /// User's place lists (legacy) - proxies to listsViewModel
    var userLists: [PlaceList] {
        get { listsViewModel.userLists }
        set { listsViewModel.userLists = newValue }
    }

    /// Places in each list by list ID - proxies to listsViewModel
    var userListsPlaces: [String: [String]] {
        get { listsViewModel.userListsPlaces }
        set { listsViewModel.userListsPlaces = newValue }
    }

    /// Place counts per list - proxies to listsViewModel
    var placeListCounts: [UUID: Int] {
        get { listsViewModel.placeListCounts }
        set { listsViewModel.placeListCounts = newValue }
    }

    /// Lightweight place lists by proximity - proxies to listsViewModel
    var lightweightPlaceLists: [LightweightPlaceList] {
        get { listsViewModel.lightweightPlaceLists }
        set { listsViewModel.lightweightPlaceLists = newValue }
    }

    /// Places in each lightweight list - proxies to listsViewModel
    var lightweightPlaceListPlaces: [String: [LightweightPlace]] {
        get { listsViewModel.lightweightPlaceListPlaces }
        set { listsViewModel.lightweightPlaceListPlaces = newValue }
    }

    /// Place counts for lightweight lists - proxies to listsViewModel
    var lightweightPlaceListCounts: [String: Int] {
        get { listsViewModel.lightweightPlaceListCounts }
        set { listsViewModel.lightweightPlaceListCounts = newValue }
    }
    // Map filtering triggers
    @Published var selectedListIdForMap: String? = nil // When set, triggers map to show only this list's annotations (String because LightweightPlaceList.id is String)
    @Published var showTikToksOnMap: Bool = false // When set, triggers map to show TikTok places
    @Published var showReviewsOnMap: Bool = false // When set, triggers map to show reviewed places
    @Published var showFavoritesOnMap: Bool = false // When set, triggers map to show favorite places
    @Published var showMyPlacesOnMap: Bool = false // When set, triggers map to show user's created places
    /// Loading more lists (pagination) - proxies to listsViewModel
    var isLoadingMorePlaceLists: Bool {
        get { listsViewModel.isLoadingMorePlaceLists }
        set { listsViewModel.isLoadingMorePlaceLists = newValue }
    }

    /// Has more lists to load - proxies to listsViewModel
    var hasMorePlaceLists: Bool {
        get { listsViewModel.hasMorePlaceLists }
        set { listsViewModel.hasMorePlaceLists = newValue }
    }

    /// Current page for list pagination - proxies to listsViewModel
    var placeListsCurrentPage: Int {
        get { listsViewModel.placeListsCurrentPage }
        set { listsViewModel.placeListsCurrentPage = newValue }
    }

    /// Loading initial lists - proxies to listsViewModel
    var isLoadingInitialLists: Bool {
        get { listsViewModel.isLoadingInitialLists }
        set { listsViewModel.isLoadingInitialLists = newValue }
    }

    /// Show only shared/collaborative lists - proxies to listsViewModel
    var showOnlySharedLists: Bool {
        get { listsViewModel.showOnlySharedLists }
        set { listsViewModel.showOnlySharedLists = newValue }
    }

    /// Searching lists state - proxies to listsViewModel
    var isSearchingLists: Bool {
        get { listsViewModel.isSearchingLists }
        set { listsViewModel.isSearchingLists = newValue }
    }

    /// List search text - proxies to listsViewModel
    var listSearchText: String {
        get { listsViewModel.listSearchText }
        set { listsViewModel.listSearchText = newValue }
    }

    /// Count of collaborative lists - proxies to listsViewModel
    var collaborativeListCount: Int {
        listsViewModel.collaborativeListCount
    }

    /// Whether there are any collaborative lists - proxies to listsViewModel
    var hasSharedLists: Bool {
        listsViewModel.hasSharedLists
    }

    /// Whether the Shared filter can be interacted with - proxies to listsViewModel
    var canInteractWithSharedFilter: Bool {
        listsViewModel.canInteractWithSharedFilter
    }

    /// Filtered place lists based on current filter state - proxies to listsViewModel
    var filteredPlaceLists: [LightweightPlaceList] {
        listsViewModel.filteredPlaceLists
    }

    // MARK: - Child ViewModels (Composition)

    /// Child ViewModel for social features (followers, following, follow actions)
    let socialViewModel: ProfileSocialViewModel

    /// Child ViewModel for account management (deletion flow)
    let accountViewModel: ProfileAccountViewModel

    /// Child ViewModel for favorites management
    let favoritesViewModel: ProfileFavoritesViewModel

    /// Child ViewModel for user-created places (My Places)
    let myPlacesViewModel: ProfileMyPlacesViewModel

    /// Child ViewModel for reviewed places
    let reviewsViewModel: ProfileReviewsViewModel

    /// Child ViewModel for TikTok/external places
    let tikTokViewModel: ProfileTikTokViewModel

    /// Child ViewModel for place lists management
    let listsViewModel: ProfileListsViewModel

    /// Recently created list ID - proxies to listsViewModel
    var recentlyCreatedListId: UUID? {
        get { listsViewModel.recentlyCreatedListId }
        set { listsViewModel.recentlyCreatedListId = newValue }
    }

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

     @Published var isLoading: Bool = true
     @Published var isUploadingProfilePhoto: Bool = false

     /// Total list count - proxies to listsViewModel
     var totalListCount: Int {
         get { listsViewModel.totalListCount }
         set { listsViewModel.totalListCount = newValue }
     }

     @Published var totalUniquePlacesCount: Int = 0  // Total unique places (saved + reviewed + created)

    // Lazy loading state for lists - proxies to listsViewModel
    /// Loaded list IDs - proxies to listsViewModel
    var loadedListIds: Set<UUID> {
        get { listsViewModel.loadedListIds }
        set { listsViewModel.loadedListIds = newValue }
    }

    /// Currently loading list IDs - proxies to listsViewModel
    var loadingListIds: Set<UUID> {
        get { listsViewModel.loadingListIds }
        set { listsViewModel.loadingListIds = newValue }
    }

    /// Pagination state for places within each list - proxies to listsViewModel
    var listPlacePagination: [String: ListPlacePagination] {
        get { listsViewModel.listPlacePagination }
        set { listsViewModel.listPlacePagination = newValue }
    }

    // Performance optimization: image preloading cache
    @Published var preloadedImages: [String: Bool] = [:] // [imageURL: isPreloaded]

    // Concurrency control for list loading
    private let maxConcurrentListLoads = 2
    private var activeListLoadTasks: [UUID: Task<Void, Never>] = [:]

    // List search cancellable
    private var listSearchCancellable: AnyCancellable?

    // Place notes
    @Published var placeNotes: [String: PlaceNote] = [:] // [placeId: PlaceNote]
    
    // Location manager for distance calculations
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    init(userSession: UserSession, userService: UserService, detailPlaceViewModel: DetailPlaceViewModel, imageService: ImageService, placeService: PlaceService, postService: PostService, locationManager: LocationManager, deepLinkManager: DeepLinkManager? = nil, deepLinkViewModel: DeepLinkViewModel? = nil, userProfileViewModel: UserProfileViewModel? = nil) {
        // Initialize child ViewModels first (must happen before self is fully initialized)
        self.socialViewModel = ProfileSocialViewModel(userService: userService, userSession: userSession)
        self.accountViewModel = ProfileAccountViewModel(userService: userService, userSession: userSession)
        self.favoritesViewModel = ProfileFavoritesViewModel(userSession: userSession)

        self.myPlacesViewModel = ProfileMyPlacesViewModel(userService: userService, userSession: userSession)
        self.reviewsViewModel = ProfileReviewsViewModel(userService: userService, userSession: userSession)
        self.tikTokViewModel = ProfileTikTokViewModel(userService: userService, userSession: userSession)
        self.listsViewModel = ProfileListsViewModel(userService: userService, placeService: placeService, userSession: userSession, locationManager: locationManager)

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

        // Wire up child ViewModel callbacks for cross-cutting map concerns
        setupFavoritesCallbacks()
        setupMyPlacesCallbacks()
        setupReviewsCallbacks()
        setupListsCallbacks()
        setupTikTokCallbacks()

        // Observe location changes using Combine
        setupLocationObserver()

        // Setup reactive data loading (MVVM + SRP)
        setupDataLoadingObserver()

        // Setup list search observer with debouncing
        setupListSearchObserver()

        // Forward child ViewModel changes to parent for SwiftUI observation
        setupChildViewModelObservers()

        // Observe TikTok multiple places notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TikTokMultiplePlacesFound"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let places = notification.userInfo?["places"] as? [DetailPlace],
               let tikTokUrl = notification.userInfo?["tikTokUrl"] as? String {
                Task { @MainActor in
                    self?.tikTokViewModel.handleMultiplePlacesNotification(places: places, tikTokUrl: tikTokUrl)
                }
            } else if let places = notification.userInfo?["places"] as? [DetailPlace] {
                Task { @MainActor in
                    self?.tikTokViewModel.handleMultiplePlaces(places)
                }
            }
        }
     }

    /// Wires up callbacks from favoritesViewModel for cross-cutting map concerns.
    private func setupFavoritesCallbacks() {
        favoritesViewModel.onPlaceSaversUpdate = { [weak self] placeId, userId, isAdding in
            self?.updatePlaceSavers(placeId: placeId, userId: userId, isAdding: isAdding)
        }
        favoritesViewModel.onAnnotationPlacesRecalculate = { [weak self] in
            self?.detailPlaceViewModel.calculateAnnotationPlaces()
        }
    }

    /// Wires up callbacks from myPlacesViewModel for cross-cutting map concerns.
    private func setupMyPlacesCallbacks() {
        myPlacesViewModel.onPlaceSaversUpdate = { [weak self] placeId, userId, isAdding in
            self?.updatePlaceSavers(placeId: placeId, userId: userId, isAdding: isAdding)
        }
        myPlacesViewModel.onPlaceRemoveFromAnnotations = { [weak self] placeId in
            self?.detailPlaceViewModel.places.removeValue(forKey: placeId)
        }
    }

    /// Wires up callbacks from reviewsViewModel for cross-cutting map concerns.
    private func setupReviewsCallbacks() {
        reviewsViewModel.onLoadPlaceDetails = { [weak self] lightweightPlaces, userId in
            await self?.loadPlaceDetailsForReviews(lightweightPlaces, userId: userId)
        }
    }

    /// Wires up callbacks from listsViewModel for cross-cutting concerns.
    private func setupListsCallbacks() {
        listsViewModel.onPlaceSaversUpdate = { [weak self] placeId, userId, isAdding in
            self?.updatePlaceSavers(placeId: placeId, userId: userId, isAdding: isAdding)
        }
    }

    /// Wires up callbacks from tikTokViewModel for cross-cutting concerns.
    private func setupTikTokCallbacks() {
        tikTokViewModel.onRefreshTikTokPlaces = { [weak self] in
            self?.refreshTikTokPlacesAfterImport()
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
    
    /// Sets up debounced observer for list search text changes
    private func setupListSearchObserver() {
        listSearchCancellable = listsViewModel.$listSearchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] (_: String) in
                Task { @MainActor [weak self] in
                    await self?.listsViewModel.performListSearch()
                }
            }
    }
    
    /// Observe user state and automatically load dependent data when user becomes available
    /// This ensures data loads after login without view intervention (MVVM + SRP)
    private func setupDataLoadingObserver() {
        $user
            .map { $0?.id }         // Map to Optional<String> first
            .removeDuplicates()     // Compare optionals: nil → "abc" is NOT a duplicate
            .compactMap { $0 }      // Filter out nil AFTER deduplication
            .sink { [weak self] userId in
                guard let self = self else { return }
                
                
                // Automatically load TikToks and reviews when user becomes available
                // This happens after login, ensuring data is ready for views
                Task {
                    async let tikToksLoad: () = self.loadInitialExternalPlaces()
                    async let reviewsLoad: () = self.loadMyReviewedPlacesWithPagination()
                    
                    // Run in parallel for efficiency
                    _ = await (tikToksLoad, reviewsLoad)
                }
            }
            .store(in: &cancellables)
    }

    /// Forwards child ViewModel objectWillChange to parent for SwiftUI observation.
    /// Required because SwiftUI doesn't automatically observe nested ObservableObjects.
    private func setupChildViewModelObservers() {
        socialViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        accountViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        favoritesViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        myPlacesViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        reviewsViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        tikTokViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        listsViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
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
        let supabase = SupabaseManager.shared
        
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
    
    /// Toggles follow/unfollow state for a user - delegates to socialViewModel.
    func toggleFollowUser(userId: String) {
        socialViewModel.toggleFollowUser(userId: userId, currentUserId: user?.id)
    }

    /// Updates local following state after external follow/unfollow action - delegates to socialViewModel.
    /// This does NOT make an API call - it only updates local state.
    func updateFollowingState(userId: String, isFollowing: Bool) {
        socialViewModel.updateFollowingState(userId: userId, isFollowing: isFollowing)
    }
    
    /// Update friend IDs in MapViewModel for viewport filtering
    // updateMapViewModelFriendIds removed - friend tracking is now handled by the PostgreSQL function
    
     private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
         let totalSize = CGSize(width: 60, height: 30)
         let singleCircleSize = CGSize(width: 30, height: 30)
         let renderer = UIGraphicsImageRenderer(size: totalSize)
        
         return renderer.image { context in
             let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
             let secondRect = CGRect(x: 11, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
             let thirdRect = CGRect(x: 22, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            
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
        // Insert at index 0 so new places appear first (matches DB sort_order behavior)
        if var existingPlaces = lightweightPlaceListPlaces[listId] {
            if !existingPlaces.contains(where: { $0.place_id == placeId }) {
                existingPlaces.insert(lightweightPlace, at: 0)  // Prepend, not append
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
    
    // MARK: - Favorites (Delegates to favoritesViewModel)

    /// Adds a place to favorites - delegates to favoritesViewModel.
    func addFavoritePlace(place: DetailPlace) {
        favoritesViewModel.addFavoritePlace(place: place)
    }

    /// Removes a place from favorites - delegates to favoritesViewModel.
    func removeFavoritePlace(place: DetailPlace) {
        favoritesViewModel.removeFavoritePlace(place: place)
    }

    /// Checks if a place is in the user's favorites - delegates to favoritesViewModel.
    func isPlaceFavorite(placeId: String) -> Bool {
        return favoritesViewModel.isPlaceFavorite(placeId: placeId)
    }

    /// Updates placeSavers dictionary for map display (cross-cutting concern kept in parent).
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
    
    // MARK: - TikTok Place Flagging (Delegates to tikTokViewModel)

    /// Flags a TikTok place - delegates to tikTokViewModel.
    func flagTikTokPlace(for placeId: String, flagType: TikTokPlaceFlagType, tikTokUrl: String? = nil, userComment: String? = nil) {
        tikTokViewModel.flagTikTokPlace(for: placeId, flagType: flagType, tikTokUrl: tikTokUrl, userComment: userComment)
    }

    /// Loads a TikTok place flag - delegates to tikTokViewModel.
    func loadTikTokPlaceFlag(for placeId: String) {
        tikTokViewModel.loadTikTokPlaceFlag(for: placeId)
    }

    /// Removes a TikTok place flag - delegates to tikTokViewModel.
    func removeTikTokPlaceFlag(for placeId: String) {
        tikTokViewModel.removeTikTokPlaceFlag(for: placeId)
    }

    /// Gets a TikTok place flag - delegates to tikTokViewModel.
    func getTikTokPlaceFlag(for placeId: String) -> TikTokPlaceFlag? {
        return tikTokViewModel.getTikTokPlaceFlag(for: placeId)
    }

    /// Checks if a TikTok place has been flagged - delegates to tikTokViewModel.
    func hasFlaggedTikTokPlace(placeId: String) -> Bool {
        return tikTokViewModel.hasFlaggedTikTokPlace(placeId: placeId)
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
    
    /// Deletes a lightweight place list from database and removes from local state
    func deleteLightweightList(_ list: LightweightPlaceList) async -> Result<Void, Error> {
        do {
            // Delete from database
            try await PlaceListService.shared.deleteList(listId: list.list_id)
            
            // Remove from local state
            lightweightPlaceLists.removeAll { $0.list_id == list.list_id }
            lightweightPlaceListPlaces.removeValue(forKey: list.list_id)
            lightweightPlaceListCounts.removeValue(forKey: list.list_id)
            
            return .success(())
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
                 socialViewModel.userFollowing.first(where: { $0.id == userId })
             }
         
         return uniqueUsers
     }
    
     /// Check if a place is in any of the user's lists (uses SQL function)
     func isPlaceInAnyList(placeId: String) async -> Bool {
         guard let userId = userSession.currentUserId else { return false }
         
         do {
             return try await PlaceListService.shared.isPlaceInAnyUserList(
                 userId: userId,
                 placeId: placeId
             )
         } catch {
             print("❌ [ProfileViewModel] Error checking place list membership: \(error)")
             return false
         }
     }

    /// Returns the count of places in the PlaceList with the given id, or 0 if not found
    func placeCount(forListId listId: UUID) -> Int {
        return userLists.first(where: { $0.id == listId })?.places.count ?? 0
    }
    
    func refreshUserPlaces() async {
        // Combine all place IDs from favorites and all lists, then de-duplicate
        var allPlaceIds = Set(favoritesViewModel.userFavorites)
        for list in listsViewModel.userListsPlaces.values {
            allPlaceIds.formUnion(list)
        }
        await detailPlaceViewModel.refreshPlaces(detailPlaces: Array(allPlaceIds))
    }

    // MARK: - Reviews (Delegates to reviewsViewModel)

    /// Loads initial reviewed places - delegates to reviewsViewModel.
    func loadMyReviewedPlacesWithPagination() async {
        await reviewsViewModel.loadMyReviewedPlacesWithPagination()
    }

    /// Loads more reviewed places (pagination) - delegates to reviewsViewModel.
    func loadMoreMyReviews() async {
        await reviewsViewModel.loadMoreMyReviews()
    }

    /// Loads full place details for reviewed places (callback from reviewsViewModel).
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

    /// Gets reviewed places for display (uses cross-cutting detailPlaceViewModel data).
    func getMyReviewedPlaces() -> [DetailPlace] {
        return reviewsViewModel.lightweightReviewedPlaces.compactMap { detailPlaceViewModel.places[$0.place_id] }
    }

    // MARK: - TikTok Places Refresh After Import
    
    // MARK: - External Places (Delegates to tikTokViewModel)

    /// Refreshes TikTok places list after a successful import - delegates to tikTokViewModel.
    func refreshTikTokPlacesAfterImport() {
        tikTokViewModel.refreshTikTokPlacesAfterImport()
    }

    /// Loads initial external places (TikTok places) - delegates to tikTokViewModel.
    func loadInitialExternalPlaces() async {
        await tikTokViewModel.loadInitialExternalPlaces()
    }

    /// Loads more external places (pagination) - delegates to tikTokViewModel.
    func loadMoreExternalPlaces() async {
        await tikTokViewModel.loadMoreExternalPlaces()
    }
    
    // MARK: - My Places (Delegates to myPlacesViewModel)

    /// Loads initial my places - delegates to myPlacesViewModel.
    func loadInitialMyPlaces() async {
        await myPlacesViewModel.loadInitialMyPlaces()
    }

    /// Loads more my places (pagination) - delegates to myPlacesViewModel.
    func loadMoreMyPlaces() async {
        await myPlacesViewModel.loadMoreMyPlaces()
    }

    // MARK: - TikTok Place Deletion

    /// Deletes a TikTok place with completion handler.
    func deleteTikTokPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        guard let userId = user?.id else {
            completion(false)
            return
        }

        let placeId = place.id.uuidString

        // Optimistic update: Remove from all local collections immediately
        removeFromLocalTikTokState(placeId: placeId, userId: userId)

        // Call backend to delete the TikTok place
        userService.deleteTikTokPlace(userId: userId, placeId: placeId) { error in
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
    
    /// Removes TikTok place from all local state collections.
    private func removeFromLocalTikTokState(placeId: String, userId: String) {
        // Delegate TikTok-specific state cleanup to tikTokViewModel
        tikTokViewModel.removeFromLocalTikTokState(placeId: placeId)
        tikTokViewModel.userExternalPlaces.removeValue(forKey: placeId)

        // Cross-cutting map concerns (kept in parent ViewModel)
        if var savers = detailPlaceViewModel.placeSavers[placeId] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            } else {
                detailPlaceViewModel.placeSavers[placeId] = savers
            }
        }

        detailPlaceViewModel.places.removeValue(forKey: placeId)
        detailPlaceViewModel.calculateAnnotationPlaces()
    }

    /// Updates a TikTok place association by external place ID (used from PlaceDetailView).
    func updateTikTokPlaceById(externalPlaceId: String, newPlaceId: String, newPlaceName: String) async {
        guard let userId = user?.id else {
            print("❌ [ProfileViewModel] Cannot update TikTok place: missing userId")
            return
        }

        // Find the existing place to get old placeId for tracking updates
        let existingPlace = tikTokViewModel.lightweightExternalPlaces.first { $0.external_place_id == externalPlaceId }
        let oldPlaceId = existingPlace?.place_id

        // Optimistic update: Update local state immediately
        if let index = tikTokViewModel.lightweightExternalPlaces.firstIndex(where: { $0.external_place_id == externalPlaceId }) {
            let original = tikTokViewModel.lightweightExternalPlaces[index]
            let updatedPlace = LightweightPlace(
                place_id: newPlaceId,
                name: newPlaceName,
                latest_review_photo: original.latest_review_photo,
                external_place_id: externalPlaceId,
                tiktok_url: original.tiktok_url,
                added_by_user_id: original.added_by_user_id,
                added_by_name: original.added_by_name,
                added_by_photo_url: original.added_by_photo_url
            )
            tikTokViewModel.lightweightExternalPlaces[index] = updatedPlace
        }

        // Update ID tracking
        if let old = oldPlaceId {
            tikTokViewModel.allTikTokPlaceIds.removeAll { $0 == old }
        }
        if !tikTokViewModel.allTikTokPlaceIds.contains(newPlaceId) {
            tikTokViewModel.allTikTokPlaceIds.append(newPlaceId)
        }

        // Persist to backend
        do {
            try await userService.updateTikTokPlaceAssociation(
                externalPlaceId: externalPlaceId,
                newPlaceId: newPlaceId,
                userId: userId
            )
            print("✅ [ProfileViewModel] Updated TikTok place to \(newPlaceId)")
        } catch {
            print("❌ [ProfileViewModel] Error updating TikTok place: \(error.localizedDescription)")
            // Revert optimistic update on failure
            refreshTikTokPlacesAfterImport()
        }
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
    
    // MARK: - TikTok Processing (Delegation to tikTokViewModel)

    /// Processes a shared TikTok URL - delegates to tikTokViewModel.
    func processSharedTikTokURL(
        _ urlString: String,
        tikTokService: TikTokService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel
    ) async -> Bool {
        return await tikTokViewModel.processSharedTikTokURL(
            urlString,
            tikTokService: tikTokService,
            selectedPlaceVM: selectedPlaceVM,
            placeVM: placeVM,
            deepLinkManager: deepLinkManager,
            deepLinkViewModel: deepLinkViewModel
        )
    }

    /// Clears TikTok import error - delegates to tikTokViewModel.
    func clearTikTokImportError() {
        tikTokViewModel.clearTikTokImportError()
    }

    /// Clears place selection state - delegates to tikTokViewModel.
    func clearPlaceSelection() {
        tikTokViewModel.clearPlaceSelection()
    }

    /// Clears the no places found state - delegates to tikTokViewModel.
    func clearNoPlacesFound() {
        tikTokViewModel.clearNoPlacesFound(deepLinkManager: deepLinkManager, deepLinkViewModel: deepLinkViewModel)
    }

    /// Called when the place selection view appears - delegates to tikTokViewModel.
    func placeSelectionViewAppeared() {
        tikTokViewModel.placeSelectionViewAppeared(deepLinkManager: deepLinkManager, deepLinkViewModel: deepLinkViewModel)
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
        
        _ = await MainActor.run {
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
        
        // Clear TikTok/external places data (delegated to child ViewModel)
        tikTokViewModel.resetAllData()

        // Clear reviewed places (delegated to child ViewModel)
        reviewsViewModel.resetAllData()

        // Clear lists (delegated to child ViewModel)
        listsViewModel.resetAllData()

        // Clear favorites (delegated to child ViewModel)
        favoritesViewModel.resetAllData()

        // Clear my places (delegated to child ViewModel)
        myPlacesViewModel.resetAllData()

        // Clear social data (delegated to child ViewModel)
        socialViewModel.resetAllData()

        // Clear account deletion state (delegated to child ViewModel)
        accountViewModel.resetAllData()

        // Clear place notes (flags are handled by tikTokViewModel.resetAllData())
        placeNotes.removeAll()

        // Reset loading states
        isLoadingInitialLists = false
        isLoadingMorePlaceLists = false
        // Note: TikTok loading states are reset via tikTokViewModel.resetAllData() above
        // Note: Social loading states are reset via socialViewModel.resetAllData() above
        // Note: My Places loading states are reset via myPlacesViewModel.resetAllData() above
        // Note: Reviews loading states are reset via reviewsViewModel.resetAllData() above
        // Note: Lists loading states are reset via listsViewModel.resetAllData() above

        // Clear other state
        preloadedImages.removeAll()
        totalUniquePlacesCount = 0
        hasPerformedInitialSort = false

        // Clear UI state flags
        isUploadingProfilePhoto = false
        // Note: TikTok UI flags are reset via tikTokViewModel.resetAllData() above
        // Note: showFollowError and followErrorMessage are reset via socialViewModel.resetAllData() above
        // Note: showMaxFavoritesAlert is reset via favoritesViewModel.resetAllData() above

        print("✅ [ProfileViewModel] All user data cleared")
    }
    
    /// Handles a TikTok notification by processing the URL - delegates to tikTokViewModel.
    func handleTikTokNotification(
        url: String,
        tikTokService: TikTokService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel
    ) {
        tikTokViewModel.handleTikTokNotification(
            url: url,
            tikTokService: tikTokService,
            selectedPlaceVM: selectedPlaceVM,
            placeVM: placeVM,
            deepLinkManager: deepLinkManager,
            deepLinkViewModel: deepLinkViewModel
        )
    }

    /// Checks for pending TikTok URL in UserDefaults - delegates to tikTokViewModel.
    func checkPendingTikTokURL(
        tikTokService: TikTokService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel
    ) {
        tikTokViewModel.checkPendingTikTokURL(
            tikTokService: tikTokService,
            selectedPlaceVM: selectedPlaceVM,
            placeVM: placeVM,
            deepLinkManager: deepLinkManager,
            deepLinkViewModel: deepLinkViewModel
        )
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
    
    /// Checks if a list is recently created - delegates to listsViewModel.
    func isListRecentlyCreated(_ listId: UUID) -> Bool {
        return listsViewModel.isListRecentlyCreated(listId)
    }
    
    /// Sets the recently created list ID - delegates to listsViewModel.
    func setRecentlyCreatedList(_ listId: UUID) {
        listsViewModel.setRecentlyCreatedList(listId)
    }

    /// Clears the recently created list flag - delegates to listsViewModel.
    func clearRecentlyCreatedList() {
        listsViewModel.clearRecentlyCreatedList()
    }
    
    // MARK: - External Places (TikTok-sourced places)

    /// Populates the userExternalPlaces dictionary and loads thumbnails as place images.
    func fetchUserExternalPlaces() async {
        // Delegate core fetching to tikTokViewModel
        await tikTokViewModel.fetchUserExternalPlaces()

        // Load thumbnails as place images (cross-cutting concern with detailPlaceViewModel)
        for externalPlace in tikTokViewModel.userExternalPlaces.values {
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
    
    /// Checks if user has TikTok videos for a specific place - delegates to tikTokViewModel.
    func hasTikTokVideos(for placeId: String) -> Bool {
        return tikTokViewModel.hasTikTokVideos(for: placeId)
    }

    /// Get TikTok videos for a place using cached metadata.
    func getTikTokVideosSync(for placeId: String) -> [TikTokVideo] {
        // Get all external places for this place ID from cache
        let matchingPlaces = tikTokViewModel.userExternalPlaces.values.filter { $0.placeId == placeId && $0.url != nil && !$0.url!.isEmpty }
        let currentUserId = userSession.currentUserId

        var videos: [TikTokVideo] = []
        for externalPlace in matchingPlaces {
            guard let url = externalPlace.url else { continue }

            // Try to get metadata from cache
            if var video = TikTokMetadataCache.shared.getCachedMetadata(for: url) {
                video.savedByUserId = currentUserId
                video.externalPlaceId = externalPlace.id
                videos.append(video)
            } else {
                // Create basic video if no cached metadata
                let videoId = extractVideoIdFromTikTokURL(url) ?? UUID().uuidString
                var basicVideo = TikTokVideo(
                    videoID: videoId,
                    url: url,
                    title: nil,
                    caption: nil,
                    embedHTML: "",
                    thumbnailURL: "",
                    author: TikTokAuthor(displayName: "", url: "", username: ""),
                    hashtags: [],
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
                basicVideo.savedByUserId = currentUserId
                basicVideo.externalPlaceId = externalPlace.id
                videos.append(basicVideo)
            }
        }

        return videos
    }

    /// Extract video ID from TikTok URL.
    private func extractVideoIdFromTikTokURL(_ url: String) -> String? {
        let patterns = [
            "/photo/([0-9]+)",
            "/video/([0-9]+)",
            "@[^/]+/video/([0-9]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(location: 0, length: url.count)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }

        return nil
    }
    
    /// Gets the external place data for a specific place ID - delegates to tikTokViewModel.
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return tikTokViewModel.getExternalPlace(for: placeId)
    }

    /// Gets first TikTok thumbnail URL for a place - delegates to tikTokViewModel.
    func getFirstTikTokThumbnailURL(for placeId: String) -> String? {
        return tikTokViewModel.getFirstTikTokThumbnailURL(for: placeId)
    }
    
    /// Loads an image from URL and stores it in placeImages.
    private func loadImageFromURL(imageUrl: String, placeId: String) async {
        guard let url = URL(string: imageUrl) else {
            print("❌ [ProfileViewModel] Invalid image URL for place \(placeId): \(imageUrl)")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.detailPlaceViewModel.placeImages[placeId] = image
                }
            }
        } catch {
            print("❌ [ProfileViewModel] Error loading image for \(placeId): \(error.localizedDescription)")
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
        myPlacesViewModel.myPlaces.removeAll { $0 == placeId }
        
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
                    myPlacesViewModel.myPlaces.append(placeId)
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
    
    /// Removes my place from local state - delegates to myPlacesViewModel.
    private func removeFromLocalMyPlacesState(placeId: String, userId: String) {
        myPlacesViewModel.removeFromLocalState(placeId: placeId)
    }

}

