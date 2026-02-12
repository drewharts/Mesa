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


// MARK: - Profile Data Loading State
enum ProfileDataLoadingState {
    case idle
    case loading
    case loaded
    case error
}

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

    /// Child ViewModel for place notes management
    let notesViewModel: ProfileNotesViewModel

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
    var userProfileNavigationViewModel: UserProfileNavigationViewModel?
    weak var mapViewModel: MapViewModel?  // For updating friends' places in viewport

     @Published var isLoading: Bool = true
     @Published var isUploadingProfilePhoto: Bool = false
     @Published var profileCountsLoadingState: ProfileDataLoadingState = .idle

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

    // List search cancellable
    private var listSearchCancellable: AnyCancellable?

    // Place notes - proxied to notesViewModel
    var placeNotes: [String: PlaceNote] {
        get { notesViewModel.placeNotes }
        set { notesViewModel.placeNotes = newValue }
    }
    
    // Location manager for distance calculations
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    init(userSession: UserSession, userService: UserService, detailPlaceViewModel: DetailPlaceViewModel, imageService: ImageService, placeService: PlaceService, postService: PostService, locationManager: LocationManager, deepLinkManager: DeepLinkManager? = nil, deepLinkViewModel: DeepLinkViewModel? = nil) {
        // Initialize child ViewModels first (must happen before self is fully initialized)
        self.socialViewModel = ProfileSocialViewModel(userService: userService, userSession: userSession)
        self.accountViewModel = ProfileAccountViewModel(userService: userService, userSession: userSession)
        self.favoritesViewModel = ProfileFavoritesViewModel(userSession: userSession)

        self.myPlacesViewModel = ProfileMyPlacesViewModel(userService: userService, userSession: userSession, placeService: placeService)
        self.reviewsViewModel = ProfileReviewsViewModel(userService: userService, userSession: userSession, placeService: placeService, postService: postService)
        self.tikTokViewModel = ProfileTikTokViewModel(userService: userService, userSession: userSession)
        self.listsViewModel = ProfileListsViewModel(userService: userService, placeService: placeService, userSession: userSession, locationManager: locationManager)
        self.notesViewModel = ProfileNotesViewModel(userService: userService, userSession: userSession)

        self.userService = userService
        self.detailPlaceViewModel = detailPlaceViewModel
        self.userSession = userSession
        self.imageService = imageService
        self.placeService = placeService
        self.postService = postService
        self.locationManager = locationManager
        self.deepLinkManager = deepLinkManager
        self.deepLinkViewModel = deepLinkViewModel

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
        myPlacesViewModel.onPlacesUpdate = { [weak self] placeId, place in
            self?.detailPlaceViewModel.places[placeId] = place
        }
        myPlacesViewModel.onAnnotationPlacesRecalculate = { [weak self] in
            self?.detailPlaceViewModel.calculateAnnotationPlaces()
        }
        myPlacesViewModel.getPlaceSavers = { [weak self] placeId in
            self?.detailPlaceViewModel.placeSavers[placeId]
        }
    }

    /// Wires up callbacks from reviewsViewModel for cross-cutting map concerns.
    private func setupReviewsCallbacks() {
        reviewsViewModel.onPlacesUpdate = { [weak self] placeId, place in
            self?.detailPlaceViewModel.places[placeId] = place
        }

        reviewsViewModel.onFetchPlaceImage = { [weak self] placeId in
            self?.detailPlaceViewModel.fetchPlaceImage(for: placeId)
        }

        reviewsViewModel.onPlaceSaversUpdate = { [weak self] placeId, userId, isAdding in
            self?.updatePlaceSavers(placeId: placeId, userId: userId, isAdding: isAdding)
        }

        reviewsViewModel.onAnnotationPlacesRecalculate = { [weak self] in
            self?.detailPlaceViewModel.calculateAnnotationPlaces()
        }

        reviewsViewModel.onPlaceImageUpdate = { [weak self] placeId, image in
            self?.detailPlaceViewModel.placeImages[placeId] = image
        }

        reviewsViewModel.hasPlaceImage = { [weak self] placeId in
            self?.detailPlaceViewModel.placeImages[placeId] != nil
        }
    }

    /// Wires up callbacks from listsViewModel for cross-cutting concerns.
    private func setupListsCallbacks() {
        listsViewModel.onPlaceSaversUpdate = { [weak self] placeId, userId, isAdding in
            self?.updatePlaceSavers(placeId: placeId, userId: userId, isAdding: isAdding)
        }

        listsViewModel.getPlaceCoordinate = { [weak self] placeId in
            self?.detailPlaceViewModel.places[placeId]?.coordinate
        }

        listsViewModel.onAnnotationPlacesRecalculate = { [weak self] in
            self?.detailPlaceViewModel.calculateAnnotationPlaces()
        }

        listsViewModel.onPlacesUpdate = { [weak self] placeId, place in
            self?.detailPlaceViewModel.places[placeId] = place
        }

        listsViewModel.getUserInfo = { [weak self] in
            guard let user = self?.user else { return nil }
            return (fullName: user.fullName, profilePhotoURL: user.profilePhotoURL)
        }

        listsViewModel.getPlaceSavers = { [weak self] placeId in
            self?.detailPlaceViewModel.placeSavers[placeId]
        }

        listsViewModel.onFetchPlaceImage = { [weak self] placeId in
            self?.detailPlaceViewModel.fetchPlaceImage(for: placeId)
        }

        listsViewModel.onSetLoading = { [weak self] isLoading in
            self?.isLoading = isLoading
        }

        listsViewModel.getCurrentUserId = { [weak self] in
            self?.user?.id
        }

        listsViewModel.hasPlace = { [weak self] placeId in
            self?.detailPlaceViewModel.places[placeId] != nil
        }
    }

    /// Wires up callbacks from tikTokViewModel for cross-cutting concerns.
    private func setupTikTokCallbacks() {
        tikTokViewModel.onRefreshTikTokPlaces = { [weak self] in
            self?.refreshTikTokPlacesAfterImport()
        }

        tikTokViewModel.onPlaceImageLoaded = { [weak self] placeId, image in
            self?.detailPlaceViewModel.placeImages[placeId] = image
        }

        tikTokViewModel.hasPlaceImage = { [weak self] placeId in
            self?.detailPlaceViewModel.placeImages[placeId] != nil
        }

        tikTokViewModel.onFetchPlaceImage = { [weak self] placeId in
            self?.detailPlaceViewModel.fetchPlaceImage(for: placeId)
        }

        tikTokViewModel.getCurrentUserId = { [weak self] in
            self?.user?.id
        }

        tikTokViewModel.onPlaceSaversUpdate = { [weak self] placeId, userId, isAdding in
            self?.updatePlaceSavers(placeId: placeId, userId: userId, isAdding: isAdding)
        }

        tikTokViewModel.onPlacesRemove = { [weak self] placeId in
            self?.detailPlaceViewModel.places.removeValue(forKey: placeId)
        }

        tikTokViewModel.onAnnotationPlacesRecalculate = { [weak self] in
            self?.detailPlaceViewModel.calculateAnnotationPlaces()
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
        listSearchCancellable = listsViewModel.searchViewModel.$listSearchText
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
                // Note: fetchUserExternalPlaces() is NOT called here - it's loaded on-demand
                // when navigating to PlaceDetailView to avoid unnecessary startup load
                Task {
                    async let tikToksLoad: () = self.loadInitialExternalPlaces()
                    async let reviewsLoad: () = self.loadMyReviewedPlacesWithPagination()
                    async let myPlacesLoad: () = self.loadInitialMyPlaces()

                    // Run in parallel for efficiency
                    _ = await (tikToksLoad, reviewsLoad, myPlacesLoad)
                }
            }
            .store(in: &cancellables)
    }

    /// Forwards child ViewModel objectWillChange to parent for SwiftUI observation.
    /// Only forwards VMs not directly observed by views via @ObservedObject.
    /// tikTokViewModel is forwarded because ProfileView (profile coordinator) accesses it
    /// via convenience accessor and receives profile as @EnvironmentObject (not init-injected).
    /// tikTokVM changes are rare (user-initiated TikTok import) so impact is minimal.
    private func setupChildViewModelObservers() {
        accountViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        notesViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        tikTokViewModel.objectWillChange.sink { [weak self] _ in
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
    
    /// Checks if a place is in a specific list - delegates to listsViewModel.
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        return listsViewModel.isPlaceInList(listId: listId, placeId: placeId)
    }
    
    // MARK: - Add to List Functions (Delegates to listsViewModel)

    /// Add a place to a lightweight list - delegates to listsViewModel.
    func addPlaceToLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        listsViewModel.addPlaceToLightweightList(listId: listId, place: place, updatedCount: updatedCount)
    }

    /// Add a place to a list (old UUID-based format) - delegates to listsViewModel.
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        listsViewModel.addPlaceToList(listId: listId, place: place)
    }

    /// Remove a place from a lightweight list using a DetailPlace reference.
    func removePlaceFromLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        listsViewModel.removePlaceFromLightweightList(listId: listId, place: place, updatedCount: updatedCount)
    }

    /// Remove a place from a lightweight list by place ID.
    func removePlaceFromLightweightList(listId: String, placeId: String) {
        listsViewModel.removePlaceFromLightweightList(listId: listId, placeId: placeId)
    }

    /// Remove a place from a list (old UUID-based format) - delegates to listsViewModel.
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        listsViewModel.removePlaceFromList(listId: listId, place: place)
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

    // MARK: - Place Notes (Delegates to notesViewModel)

    /// Saves a place note - delegates to notesViewModel.
    func savePlaceNote(for placeId: String, note: String?, link: String?) {
        notesViewModel.savePlaceNote(for: placeId, note: note, link: link)
    }

    /// Loads a place note - delegates to notesViewModel.
    func loadPlaceNote(for placeId: String) {
        notesViewModel.loadPlaceNote(for: placeId)
    }

    /// Deletes a place note - delegates to notesViewModel.
    func deletePlaceNote(for placeId: String) {
        notesViewModel.deletePlaceNote(for: placeId)
    }
    
    // MARK: - TikTok Place Flagging (Delegates to tikTokViewModel)

    /// Flags a TikTok place - delegates to tikTokViewModel.
    func flagTikTokPlace(for placeId: String, flagType: TikTokPlaceFlagType, tikTokUrl: String? = nil, userComment: String? = nil) {
        tikTokViewModel.flagTikTokPlace(for: placeId, flagType: flagType, tikTokUrl: tikTokUrl, userComment: userComment)
    }

    /// Records a place correction flag for analytics after user corrects a TikTok place association.
    func recordPlaceCorrectionFlag(for placeId: String, newPlaceId: String) {
        let tikTokUrl = tikTokViewModel.getExternalPlace(for: placeId)?.url
        tikTokViewModel.flagTikTokPlace(
            for: placeId,
            flagType: .wrongSuggestion,
            tikTokUrl: tikTokUrl,
            userComment: "Corrected to place: \(newPlaceId)"
        )
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
    /// Creates a new place list - delegates to listsViewModel.
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) async -> Result<PlaceList, Error> {
        return await listsViewModel.addNewPlaceList(named: name, city: city, emoji: emoji, image: image)
    }

    /// Deletes a lightweight place list - delegates to listsViewModel.
    func deleteLightweightList(_ list: LightweightPlaceList) async -> Result<Void, Error> {
        return await listsViewModel.deleteLightweightList(list)
    }

    /// Removes a place list (legacy) - delegates to listsViewModel.
    func removePlaceList(placeList: PlaceList) {
        listsViewModel.removePlaceList(placeList: placeList)
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
    
    /// Checks if a place is in any of the user's lists - delegates to listsViewModel.
    func isPlaceInAnyList(placeId: String) async -> Bool {
        return await listsViewModel.isPlaceInAnyList(placeId: placeId)
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

    // MARK: - TikTok Place Deletion (Delegates to tikTokViewModel)

    /// Deletes a TikTok place with completion handler - delegates to tikTokViewModel.
    func deleteTikTokPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        tikTokViewModel.deleteTikTokPlace(place, completion: completion)
    }

    /// Delete a TikTok place using LightweightPlace - delegates to tikTokViewModel.
    func deleteTikTokPlace(_ place: LightweightPlace) {
        tikTokViewModel.deleteTikTokPlace(place)
    }

    /// Updates a TikTok place association by external place ID - delegates to tikTokViewModel.
    func updateTikTokPlaceById(externalPlaceId: String, newPlaceId: String, newPlaceName: String) async {
        await tikTokViewModel.updateTikTokPlaceById(externalPlaceId: externalPlaceId, newPlaceId: newPlaceId, newPlaceName: newPlaceName)
    }
    // MARK: - List Sorting by Distance (Delegates to listsViewModel)

    /// Sorts userLists by their distance from the user's current location - delegates to listsViewModel.
    func sortListsByDistance() {
        listsViewModel.sortListsByDistance()
    }

    /// Recalculates the average coordinates for a specific list - delegates to listsViewModel.
    func recalculateAverageCoordinates(for listId: UUID) {
        listsViewModel.recalculateAverageCoordinates(for: listId)
    }

    /// Whether the initial sort has been performed - delegates to listsViewModel.
    var hasPerformedInitialSort: Bool {
        listsViewModel.hasCompletedInitialSort
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

    // MARK: - Legacy List Loading (Delegates to listsViewModel)

    /// Ensures lists are loaded with DetailPlace data - delegates to listsViewModel.
    func ensureListsLoaded() {
        listsViewModel.ensureListsLoaded()
    }

    /// Loads list data if needed for a specific list - delegates to listsViewModel.
    func loadListDataIfNeeded(listId: UUID) {
        listsViewModel.loadListDataIfNeeded(listId: listId)
    }

    /// Load more lists when user scrolls - delegates to listsViewModel.
    func loadMoreListsIfNeeded() {
        listsViewModel.loadMoreListsIfNeeded()
    }
    
    // MARK: - List Place Pagination Methods (Delegates to listsViewModel)

    /// Initialize pagination if needed - delegates to listsViewModel.
    func initializeListPaginationIfNeeded(listId: UUID) {
        listsViewModel.initializeListPaginationIfNeeded(listId: listId)
    }

    /// Load the next page of places for a specific list - delegates to listsViewModel.
    func loadNextPageForList(listId: UUID) {
        listsViewModel.loadNextPageForList(listId: listId)
    }

    /// Get the displayed place IDs for a list (respecting pagination) - delegates to listsViewModel.
    func getDisplayedPlaceIds(for listId: UUID) -> [String] {
        listsViewModel.getDisplayedPlaceIds(for: listId)
    }

    /// Check if a list has more places to load - delegates to listsViewModel.
    func hasMorePlaces(for listId: UUID) -> Bool {
        listsViewModel.hasMorePlaces(for: listId)
    }

    /// Check if a list is currently loading more places - delegates to listsViewModel.
    func isLoadingMorePlaces(for listId: UUID) -> Bool {
        listsViewModel.isLoadingMorePlaces(for: listId)
    }

    /// Get the total number of places in a list - delegates to listsViewModel.
    func getTotalPlaceCount(for listId: UUID) -> Int {
        listsViewModel.getTotalPlaceCount(for: listId)
    }

    /// Reset pagination for a list - delegates to listsViewModel.
    func resetListPagination(listId: UUID) {
        listsViewModel.resetListPagination(listId: listId)
    }

    /// Smart image preloading for visible places (simplified).
    func preloadImagesForVisiblePlaces(listId: UUID) {
        let displayedPlaceIds = listsViewModel.getDisplayedPlaceIds(for: listId)

        // Simple preloading without complex async - just mark as ready
        for placeId in displayedPlaceIds {
            if let place = detailPlaceViewModel.places[placeId] {
                // Preload TikTok thumbnails
                if let tikTokVideos = place.tikTokVideos,
                   let firstVideo = tikTokVideos.first,
                   !firstVideo.thumbnailURL.isEmpty {
                    preloadedImages[firstVideo.thumbnailURL] = true
                }
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

        // Clear place notes (delegated to child ViewModel)
        notesViewModel.resetAllData()

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
        // Note: hasPerformedInitialSort is reset via listsViewModel.resetAllData() above

        // Clear UI state flags
        isUploadingProfilePhoto = false
        // Note: TikTok UI flags are reset via tikTokViewModel.resetAllData() above
        // Note: showFollowError and followErrorMessage are reset via socialViewModel.resetAllData() above

        // Reset profile counts loading state
        profileCountsLoadingState = .idle

        print("✅ [ProfileViewModel] All user data cleared")
    }

    // MARK: - Profile Counts Loading

    /// Loads all profile counts, favorites, and place lists in parallel.
    /// Guards against redundant loads — only fires when state is .idle.
    func loadProfileCounts() async {
        guard profileCountsLoadingState == .idle else { return }
        guard let userId = user?.id ?? userSession.currentUserId else { return }

        profileCountsLoadingState = .loading

        socialViewModel.isFollowersLoading = true
        socialViewModel.isFollowingLoading = true
        myPlacesViewModel.isMyPlacesLoading = true

        async let followers: Int = (try? await userService.getNumberFollowers(forUserId: userId)) ?? 0
        async let following: Int = (try? await userService.getNumberFollowing(forUserId: userId)) ?? 0
        async let myPlaces: Int = (try? await userService.getNumberMyPlaces(forUserId: userId)) ?? 0
        async let totalLists: Int = (try? await userService.getTotalListCount(forUserId: userId)) ?? 0
        async let favorites: [FavoritePlace] = (try? await userService.fetchUserFavorites(userId: userId)) ?? []
        async let totalUniquePlaces: Int = (try? await userService.getTotalPlacesCount(forUserId: userId)) ?? 0

        let (followersCount, followingCount, myPlacesCount, totalListCount, favoritePlaces, uniquePlacesCount) = await (followers, following, myPlaces, totalLists, favorites, totalUniquePlaces)

        socialViewModel.followersCount = followersCount
        socialViewModel.followingCount = followingCount
        listsViewModel.totalListCount = totalListCount
        totalUniquePlacesCount = uniquePlacesCount
        myPlacesViewModel.myPlaces = Array(repeating: "", count: myPlacesCount)
        favoritesViewModel.lightweightFavorites = favoritePlaces
        socialViewModel.isFollowersLoading = false
        socialViewModel.isFollowingLoading = false
        myPlacesViewModel.isMyPlacesLoading = false

        // Update placeSavers for favorites so "Saved By" feature works
        for favorite in favoritePlaces {
            let placeId = favorite.place_id
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
        }

        profileCountsLoadingState = .loaded

        // Load lists in background — don't block profile display
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.listsViewModel.loadInitialLists()
        }
    }

    /// Resets profile counts loading state to allow a fresh fetch (e.g. pull-to-refresh).
    func invalidateProfileCounts() {
        profileCountsLoadingState = .idle
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
    
    // MARK: - External Places (Delegates to tikTokViewModel)

    /// Populates the userExternalPlaces dictionary and loads thumbnails - delegates to tikTokViewModel.
    func fetchUserExternalPlaces() async {
        await tikTokViewModel.fetchUserExternalPlaces()

        // Load thumbnails as place images (cross-cutting concern handled via callback)
        for externalPlace in tikTokViewModel.userExternalPlaces.values {
            if let url = externalPlace.url,
               let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: url) {
                Task {
                    await tikTokViewModel.loadTikTokThumbnailAsPlaceImage(
                        placeId: externalPlace.placeId,
                        thumbnailURL: thumbnailURL
                    )
                }
            }
        }
    }

    /// Ensures TikTok thumbnail is cached - delegates to tikTokViewModel.
    func ensureTikTokThumbnailCached(for placeId: String) {
        tikTokViewModel.ensureTikTokThumbnailCached(for: placeId)
    }

    /// Fetches fallback images for places - delegates to tikTokViewModel.
    func fetchFallbackImages(for placeIds: [String]) async {
        await tikTokViewModel.fetchFallbackImages(for: placeIds)
    }

    /// Gets external_place_id for a TikTok video URL - delegates to tikTokViewModel.
    func getExternalPlaceId(for placeId: String, videoUrl: String) async -> String? {
        return await tikTokViewModel.getExternalPlaceId(for: placeId, videoUrl: videoUrl)
    }

    /// Checks if user has TikTok videos for a specific place - delegates to tikTokViewModel.
    func hasTikTokVideos(for placeId: String) -> Bool {
        return tikTokViewModel.hasTikTokVideos(for: placeId)
    }

    /// Gets TikTok videos for a place using cached metadata - delegates to tikTokViewModel.
    func getTikTokVideosSync(for placeId: String) -> [TikTokVideo] {
        return tikTokViewModel.getTikTokVideosSync(for: placeId)
    }

    /// Gets the external place data for a specific place ID - delegates to tikTokViewModel.
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return tikTokViewModel.getExternalPlace(for: placeId)
    }

    /// Gets first TikTok thumbnail URL for a place - delegates to tikTokViewModel.
    func getFirstTikTokThumbnailURL(for placeId: String) -> String? {
        return tikTokViewModel.getFirstTikTokThumbnailURL(for: placeId)
    }

    /// Loads images for places with prioritization - delegates to tikTokViewModel.
    func loadPriorityImagesForPlaces(_ places: [DetailPlace], priorityCount: Int = 8) {
        tikTokViewModel.loadPriorityImagesForPlaces(places, priorityCount: priorityCount)
    }

    /// Deletes a user-created place (DetailPlace version) - delegates to myPlacesViewModel.
    func deleteMyPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        myPlacesViewModel.deleteMyPlace(place, completion: completion)
    }

    /// Deletes a user-created place (LightweightPlace version) - delegates to myPlacesViewModel.
    func deleteMyPlace(_ place: LightweightPlace) {
        myPlacesViewModel.deleteMyPlace(place)
    }

}

