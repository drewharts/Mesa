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


@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: ProfileData?
    @Published var userPicture: UIImage?

    // Map filtering triggers
    @Published var selectedListIdForMap: String? = nil // When set, triggers map to show only this list's annotations (String because LightweightPlaceList.id is String)
    @Published var showExternalPlacesOnMap: Bool = false // When set, triggers map to show external places
    @Published var showReviewsOnMap: Bool = false // When set, triggers map to show reviewed places
    @Published var showFavoritesOnMap: Bool = false // When set, triggers map to show favorite places
    @Published var showMyPlacesOnMap: Bool = false // When set, triggers map to show user's created places

    /// Deferred map filter: stores which sheet to present after the profile fullScreenCover dismisses.
    /// Unlike the showXOnMap flags, this does NOT trigger MapContainerView's onChange handlers,
    /// so no sheet is presented while the profile is still visible.
    enum PendingMapFilter {
        case externalPlaces, reviews, favorites, myPlaces
    }
    @Published var pendingMapFilter: PendingMapFilter? = nil

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

    /// Child ViewModel for external content places
    let externalContentViewModel: ProfileExternalContentViewModel

    /// Child ViewModel for place lists management
    let listsViewModel: ProfileListsViewModel

    /// Child ViewModel for place notes management
    let notesViewModel: ProfileNotesViewModel

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
     var profileCountsLoadingState: ProfileDataLoadingState = .idle

     @Published var totalUniquePlacesCount: Int = 0  // Total unique places (saved + reviewed + created)

    // List search cancellable
    private var listSearchCancellable: AnyCancellable?

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
        self.externalContentViewModel = ProfileExternalContentViewModel(userService: userService, userSession: userSession)
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
        setupExternalContentCallbacks()

        // Observe location changes using Combine
        setupLocationObserver()

        // Setup reactive data loading (MVVM + SRP)
        setupDataLoadingObserver()

        // Setup list search observer with debouncing
        setupListSearchObserver()

        // Forward child ViewModel changes to parent for SwiftUI observation
        setupChildViewModelObservers()

        // Observe external content multiple places notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExternalContentMultiplePlacesFound"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let places = notification.userInfo?["places"] as? [DetailPlace],
               let contentUrl = notification.userInfo?["tikTokUrl"] as? String {
                Task { @MainActor in
                    self?.externalContentViewModel.handleMultiplePlacesNotification(places: places, contentUrl: contentUrl)
                }
            } else if let places = notification.userInfo?["places"] as? [DetailPlace] {
                Task { @MainActor in
                    self?.externalContentViewModel.handleMultiplePlaces(places)
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

    /// Wires up callbacks from externalContentViewModel for cross-cutting concerns.
    private func setupExternalContentCallbacks() {
        externalContentViewModel.onRefreshExternalPlaces = { [weak self] in
            self?.externalContentViewModel.refreshExternalPlacesAfterImport()
        }

        externalContentViewModel.onPlaceImageLoaded = { [weak self] placeId, image in
            self?.detailPlaceViewModel.placeImages[placeId] = image
        }

        externalContentViewModel.hasPlaceImage = { [weak self] placeId in
            self?.detailPlaceViewModel.placeImages[placeId] != nil
        }

        externalContentViewModel.onFetchPlaceImage = { [weak self] placeId in
            self?.detailPlaceViewModel.fetchPlaceImage(for: placeId)
        }

        externalContentViewModel.getCurrentUserId = { [weak self] in
            self?.user?.id
        }

        externalContentViewModel.onPlaceSaversUpdate = { [weak self] placeId, userId, isAdding in
            self?.updatePlaceSavers(placeId: placeId, userId: userId, isAdding: isAdding)
        }

        externalContentViewModel.onPlacesRemove = { [weak self] placeId in
            self?.detailPlaceViewModel.places.removeValue(forKey: placeId)
        }

        externalContentViewModel.onAnnotationPlacesRecalculate = { [weak self] in
            self?.detailPlaceViewModel.calculateAnnotationPlaces()
        }
    }

    private func setupLocationObserver() {
        // Sort immediately when location becomes available (no need to wait for places to load)
        locationManager.$currentLocation
            .dropFirst() // Skip the initial nil value
            .sink { [weak self] location in
                if location != nil && !(self?.listsViewModel.hasCompletedInitialSort ?? false) {
                    Task { @MainActor in
                        self?.listsViewModel.sortListsByDistance()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Sets up debounced observer for list search text changes
    private func setupListSearchObserver() {
        listSearchCancellable = listsViewModel.searchViewModel.$listSearchText
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] (text: String) in
                Task { @MainActor [weak self] in
                    if text.trimmingCharacters(in: .whitespaces).isEmpty {
                        await self?.listsViewModel.reloadListsAfterSearch()
                    } else {
                        await self?.listsViewModel.performListSearch()
                    }
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

                // Automatically load external places and reviews when user becomes available
                // This happens after login, ensuring data is ready for views
                // Note: fetchUserExternalPlaces() is NOT called here - it's loaded on-demand
                // when navigating to PlaceDetailView to avoid unnecessary startup load
                Task {
                    async let externalPlacesLoad: () = self.externalContentViewModel.loadInitialExternalPlaces()
                    async let reviewsLoad: () = self.reviewsViewModel.loadMyReviewedPlacesWithPagination()
                    async let myPlacesLoad: () = self.myPlacesViewModel.loadInitialMyPlaces()

                    // Run in parallel for efficiency
                    _ = await (externalPlacesLoad, reviewsLoad, myPlacesLoad)
                }
            }
            .store(in: &cancellables)
    }

    /// Forwards all child ViewModel objectWillChange to parent for SwiftUI observation.
    /// Views that access child VMs via @EnvironmentObject var profile: ProfileViewModel
    /// (rather than direct @ObservedObject) need this forwarding to detect child changes.
    private func setupChildViewModelObservers() {
        socialViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        favoritesViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        listsViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        reviewsViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        myPlacesViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        accountViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        notesViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        externalContentViewModel.objectWillChange.sink { [weak self] _ in
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

    /// Checks if a place is in a specific list - delegates to listsViewModel.
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        return listsViewModel.isPlaceInList(listId: listId, placeId: placeId)
    }
    
    // MARK: - Legacy List Methods (kept until legacy removal)

    /// Add a place to a list (old UUID-based format) - delegates to listsViewModel.
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        listsViewModel.addPlaceToList(listId: listId, place: place)
    }

    /// Remove a place from a list (old UUID-based format) - delegates to listsViewModel.
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        listsViewModel.removePlaceFromList(listId: listId, place: place)
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

    /// Records a place correction flag for analytics after user corrects an external place association.
    func recordPlaceCorrectionFlag(for placeId: String, newPlaceId: String) {
        let contentUrl = externalContentViewModel.getExternalPlace(for: placeId)?.url
        externalContentViewModel.flagPlace(
            for: placeId,
            flagType: .wrongSuggestion,
            contentUrl: contentUrl,
            userComment: "Corrected to place: \(newPlaceId)"
        )
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
    
    /// Refreshes place data for all saved places across favorites and lists.
    func refreshUserPlaces() async {
        var allPlaceIds = Set(favoritesViewModel.userFavorites)
        for list in listsViewModel.userListsPlaces.values {
            allPlaceIds.formUnion(list)
        }
        await detailPlaceViewModel.refreshPlaces(detailPlaces: Array(allPlaceIds))
    }

    // MARK: - External Content Processing (Delegation to externalContentViewModel)

    /// Processes a shared external content URL - delegates to externalContentViewModel.
    func processSharedContentURL(
        _ urlString: String,
        externalContentService: ExternalContentService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel
    ) async -> Bool {
        return await externalContentViewModel.processSharedContentURL(
            urlString,
            contentService: externalContentService,
            selectedPlaceVM: selectedPlaceVM,
            placeVM: placeVM,
            deepLinkManager: deepLinkManager,
            deepLinkViewModel: deepLinkViewModel
        )
    }

    /// Clears place selection state - delegates to externalContentViewModel.
    func clearPlaceSelection() {
        externalContentViewModel.clearPlaceSelection()
    }

    /// Clears the no places found state - delegates to externalContentViewModel.
    func clearNoPlacesFound() {
        externalContentViewModel.clearNoPlacesFound(deepLinkManager: deepLinkManager, deepLinkViewModel: deepLinkViewModel)
    }

    /// Called when the place selection view appears - delegates to externalContentViewModel.
    func placeSelectionViewAppeared() {
        externalContentViewModel.placeSelectionViewAppeared(deepLinkManager: deepLinkManager, deepLinkViewModel: deepLinkViewModel)
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
        
        // Clear external places data (delegated to child ViewModel)
        externalContentViewModel.resetAllData()

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

        // Clear other state
        totalUniquePlacesCount = 0

        // Clear UI state flags
        isUploadingProfilePhoto = false
        // Note: External content UI flags are reset via externalContentViewModel.resetAllData() above
        // Note: showFollowError and followErrorMessage are reset via socialViewModel.resetAllData() above

        // Reset profile counts loading state
        profileCountsLoadingState = .idle

        print("✅ [ProfileViewModel] All user data cleared")
    }

    // MARK: - Profile Counts Loading

    /// Runs an async operation, returning the fallback on any error including task cancellation.
    private func resilientFetch<T>(_ fallback: T, _ operation: () async throws -> T) async -> T {
        do {
            return try await operation()
        } catch {
            if !(error is CancellationError) && (error as? URLError)?.code != .cancelled {
                print("⚠️ [resilientFetch] Error (keeping current value): \(error)")
            }
            return fallback
        }
    }

    /// Fetches profile counts and favorites in parallel, preserving current values on cancellation.
    func loadProfileCounts() async {
        guard profileCountsLoadingState == .idle else { return }
        guard let userId = user?.id ?? userSession.currentUserId else { return }

        profileCountsLoadingState = .loading
        let fallbacks = captureCurrentCountFallbacks()
        showLoadingIndicatorsIfInitialLoad(fallbacks)

        async let followers: Int = resilientFetch(fallbacks.followers) { try await self.userService.getNumberFollowers(forUserId: userId) }
        async let following: Int = resilientFetch(fallbacks.following) { try await self.userService.getNumberFollowing(forUserId: userId) }
        async let favorites: [FavoritePlace] = resilientFetch(fallbacks.favorites) { try await self.userService.fetchUserFavorites(userId: userId) }
        async let totalUniquePlaces: Int = resilientFetch(fallbacks.uniquePlaces) { try await self.userService.getTotalPlacesCount(forUserId: userId) }

        let (followersCount, followingCount, favoritePlaces, uniquePlacesCount) = await (followers, following, favorites, totalUniquePlaces)

        socialViewModel.followersCount = followersCount
        socialViewModel.followingCount = followingCount
        totalUniquePlacesCount = uniquePlacesCount
        favoritesViewModel.lightweightFavorites = favoritePlaces
        socialViewModel.isFollowersLoading = false
        socialViewModel.isFollowingLoading = false

        addCurrentUserToPlaceSavers(for: favoritePlaces, userId: userId)
        profileCountsLoadingState = .loaded

        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.listsViewModel.loadInitialLists()
        }
    }

    /// Captures current count values as fallbacks so cancelled queries preserve existing data.
    private func captureCurrentCountFallbacks() -> (followers: Int, following: Int, favorites: [FavoritePlace], uniquePlaces: Int) {
        return (
            socialViewModel.followersCount,
            socialViewModel.followingCount,
            favoritesViewModel.lightweightFavorites,
            totalUniquePlacesCount
        )
    }

    /// Shows loading indicators only on initial load (refresh already shows pull-to-refresh spinner).
    private func showLoadingIndicatorsIfInitialLoad(_ fallbacks: (followers: Int, following: Int, favorites: [FavoritePlace], uniquePlaces: Int)) {
        if fallbacks.followers == 0 && fallbacks.following == 0 {
            socialViewModel.isFollowersLoading = true
            socialViewModel.isFollowingLoading = true
        }
    }

    /// Marks the current user as a saver for each favorited place (for "Saved By" map display).
    private func addCurrentUserToPlaceSavers(for favorites: [FavoritePlace], userId: String) {
        for favorite in favorites {
            let placeId = favorite.place_id
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
        }
    }

    /// Resets profile counts loading state to allow a fresh fetch (e.g. pull-to-refresh).
    func invalidateProfileCounts() {
        profileCountsLoadingState = .idle
    }

    /// Refreshes all profile data for pull-to-refresh.
    func refreshProfile() async {
        invalidateProfileCounts()
        await loadProfileCounts()

        async let reviews: Void = reviewsViewModel.refreshReviewedPlaces()
        async let externalPlaces: Void = externalContentViewModel.reloadLightweightExternalPlaces()
        async let myPlaces: Void = myPlacesViewModel.refreshMyPlaces()

        _ = await (reviews, externalPlaces, myPlaces)
    }

    /// Handles an external content notification by processing the URL - delegates to externalContentViewModel.
    func handleContentNotification(
        url: String,
        externalContentService: ExternalContentService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel
    ) {
        externalContentViewModel.handleContentNotification(
            url: url,
            contentService: externalContentService,
            selectedPlaceVM: selectedPlaceVM,
            placeVM: placeVM,
            deepLinkManager: deepLinkManager,
            deepLinkViewModel: deepLinkViewModel
        )
    }

    /// Checks for pending content URL in UserDefaults - delegates to externalContentViewModel.
    func checkPendingContentURL(
        externalContentService: ExternalContentService,
        selectedPlaceVM: SelectedPlaceViewModel,
        placeVM: DetailPlaceViewModel
    ) {
        externalContentViewModel.checkPendingContentURL(
            contentService: externalContentService,
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
    
    // MARK: - External Places (Delegates to externalContentViewModel)

    /// Populates the userExternalPlaces dictionary and loads thumbnails - delegates to externalContentViewModel.
    func fetchUserExternalPlaces() async {
        await externalContentViewModel.fetchUserExternalPlaces()

        // Load thumbnails as place images (cross-cutting concern handled via callback)
        for externalPlace in externalContentViewModel.userExternalPlaces.values {
            if let url = externalPlace.url,
               let thumbnailURL = ExternalMetadataCache.shared.getCachedThumbnailUrl(for: url) {
                Task {
                    await externalContentViewModel.loadExternalThumbnailAsPlaceImage(
                        placeId: externalPlace.placeId,
                        thumbnailURL: thumbnailURL
                    )
                }
            }
        }
    }

    /// Ensures external thumbnail is cached - delegates to externalContentViewModel.
    func ensureExternalThumbnailCached(for placeId: String) {
        externalContentViewModel.ensureExternalThumbnailCached(for: placeId)
    }

    /// Fetches fallback images for places - delegates to externalContentViewModel.
    func fetchFallbackImages(for placeIds: [String]) async {
        await externalContentViewModel.fetchFallbackImages(for: placeIds)
    }

    /// Gets external_place_id for a video URL - delegates to externalContentViewModel.
    func getExternalPlaceId(for placeId: String, videoUrl: String) async -> String? {
        return await externalContentViewModel.getExternalPlaceId(for: placeId, videoUrl: videoUrl)
    }

    /// Checks if user has external videos for a specific place - delegates to externalContentViewModel.
    func hasExternalVideos(for placeId: String) -> Bool {
        return externalContentViewModel.hasExternalVideos(for: placeId)
    }

    /// Gets the external place data for a specific place ID - delegates to externalContentViewModel.
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return externalContentViewModel.getExternalPlace(for: placeId)
    }

}

