//
//  SelectedPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//

import Foundation
import CoreLocation
import UIKit

// MARK: - Services
// Note: MesaBackendService import should be available via project imports

@MainActor
class SelectedPlaceViewModel: ObservableObject {
    private let postService: PostService
    private let userService: UserService
    private let placeService: PlaceService
    private let imageService: ImageService
    private let mesaBackendService: MesaBackendService

    private let locationManager: LocationManager
    private weak var detailPlaceViewModel: DetailPlaceViewModel?

    init(locationManager: LocationManager, postService: PostService, placeService: PlaceService, userService: UserService, imageService: ImageService, mesaBackendService: MesaBackendService = MesaBackendService(), detailPlaceViewModel: DetailPlaceViewModel? = nil) {
        self.locationManager = locationManager
        self.postService = postService
        self.placeService = placeService
        self.userService = userService
        self.imageService = imageService
        self.mesaBackendService = mesaBackendService
        self.detailPlaceViewModel = detailPlaceViewModel
    }

    private var isUpdatingPlaceDetails = false
    private var isFetchingFreshDetails = false

    @Published var selectedPlace: DetailPlace? {
        didSet {
            guard !isUpdatingPlaceDetails else { return }
            handleSelectedPlaceChange()
        }
    }

    private func handleSelectedPlaceChange() {
        guard let place = selectedPlace else { return }
        guard let currentLocation = locationManager.currentLocation else { return }

        if placeNeedsCompleteDetails(place) {
            handlePlaceWithIncompleteDetails(place, currentLocation: currentLocation.coordinate)
        } else {
            continueWithPlaceSetup(place: place, currentLocation: currentLocation.coordinate)
        }
    }

    private func handlePlaceWithIncompleteDetails(_ place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        if isFetchingFreshDetails {
            continueWithPlaceSetup(place: place, currentLocation: currentLocation)
            return
        }

        fetchCompletePlaceDetails(for: place) { [weak self] freshPlace in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let freshPlace = freshPlace {
                    // Merge fresh data while preserving local-only properties (e.g., isCustom)
                    let mergedPlace = self.mergePlaceData(original: place, fresh: freshPlace)
                    
                    self.isUpdatingPlaceDetails = true
                    self.selectedPlace = mergedPlace
                    self.isUpdatingPlaceDetails = false
                    self.continueWithPlaceSetup(place: mergedPlace, currentLocation: currentLocation)
                } else {
                    print("❌ [SelectedPlaceViewModel] Failed to get complete details, continuing with current data")
                    self.continueWithPlaceSetup(place: place, currentLocation: currentLocation)
                }
            }
        }
    }

    private func placeNeedsCompleteDetails(_ place: DetailPlace) -> Bool {
        let missingRating = place.rating == nil
        let missingReviewCount = place.userRatingsTotal == nil
        let missingCategories = place.categories == nil || place.categories?.isEmpty == true
        return missingRating || missingReviewCount || missingCategories
    }

    private func continueWithPlaceSetup(place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        loadData(for: place, currentLocation: currentLocation)
        
        // Load posts (photos will be loaded automatically by PlacePhotosViewModel)
        loadPosts(for: place)

        // Set Google rating from the place data
        placeRating = place.rating ?? 0

        // Clear previous likes when loading a new place
        likedPosts.removeAll()
    }

    private func fetchCompletePlaceDetails(for place: DetailPlace, completion: @escaping (DetailPlace?) -> Void) {
        // Backend now accepts UUID and handles everything automatically
        let placeId = place.id.uuidString

        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google") { result in
            switch result {
            case .success(let completePlace):
                completion(completePlace)
            case .failure(let error):
                completion(nil)
            }
        }
    }
    
    // MARK: - Place Data Merging
    
    /// Merges fresh backend data with original place, preserving local-only properties.
    /// Single Responsibility: Handles data merging without side effects.
    ///
    /// Properties preserved from original:
    /// - `id`: Always keep the original ID
    /// - `isCustom`: Backend doesn't know about custom places
    /// - `coordinate`: Prevents selection indicator jumping when fresh data arrives
    /// - `openHours`: Preserve if fresh data doesn't have it
    private func mergePlaceData(original: DetailPlace, fresh: DetailPlace) -> DetailPlace {
        var merged = fresh
        merged.id = original.id
        merged.isCustom = original.isCustom

        // Preserve coordinate from original to prevent selection indicator jumping when fresh data arrives
        merged.coordinate = original.coordinate

        // Preserve openHours from original if fresh doesn't have it
        if merged.openHours == nil || merged.openHours?.isEmpty == true {
            merged.openHours = original.openHours
        }

        return merged
    }
    @Published var isDetailSheetPresented: Bool = false
    @Published var isRestaurantOpen: Bool = false // New property to track open status
    @Published var allowAutoPresent: Bool = true
    @Published var preservedPlaceForNavigation: DetailPlace? = nil  // Preserve place state during navigation
    @Published var shouldAnimateMapToPlace: Bool = false // Track if map should animate to place location
    @Published private var placePosts: [String: [PlacePost]] = [:] // Cache for posts by placeId
    @Published private var placeTikToks: [String: [TikTokVideo]] = [:] // Cache for TikToks by placeId
    @Published private var restaurantTypes: [String: String] = [:] // Dictionary to store restaurant types by placeId
    
    /// Increments whenever posts are modified - allows observers to react to post changes
    @Published private(set) var postsUpdateCounter: Int = 0
    
    @Published var placeRating: Double = 0
    
    @Published private var postLoadingStates: [String: LoadingState] = [:] // Loading states for posts
    @Published var isCurrentPlaceFullyLoaded: Bool = false
    
    // Add new property to track liked posts
    @Published private var likedPosts: Set<String> = []

    // MARK: - Loading State Enum
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(Error)

        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.error, .error):
                return true // All errors considered equal for simplicity
            default:
                return false
            }
        }
    }
    
    // Get restaurant type for a place
    func getRestaurantType(for placeId: String) -> String? {
        return restaurantTypes[placeId]
    }
    
    /// Update the isCurrentPlaceFullyLoaded property based on current loading states
    private func updateCurrentPlaceFullyLoaded() {
        guard let placeId = selectedPlace?.id.uuidString else {
            isCurrentPlaceFullyLoaded = false
            return
        }
        
        let postState = postLoadingStates[placeId] ?? .idle

        // Consider loaded if posts are either loaded or in error state
        // (we don't want to wait forever if there's an error)
        // Photos are managed independently by PlacePhotosViewModel
        let postsReady: Bool
        switch postState {
        case .loaded, .error:
            postsReady = true
        case .idle, .loading:
            postsReady = false
        }

        // Note: Photos are loaded separately by PlacePhotosViewModel and don't block
        // the main place detail view from loading. Each section shows its own loading state.

        let wasLoaded = isCurrentPlaceFullyLoaded
        isCurrentPlaceFullyLoaded = postsReady
        
        // Debug logging when the state changes
        // Place is now fully loaded
    }
    
    // Calculate restaurant type and store in dictionary
    func calculateAndStoreRestaurantType(for place: DetailPlace) {
        let placeId = place.id.uuidString
        let placeDetailVM = PlaceDetailViewModel()
        if let type = placeDetailVM.getRestaurantType(for: place) {
            restaurantTypes[placeId] = type
        }
    }
    
    // MARK: - Private Methods
    private func loadData(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        
        // Compute whether the restaurant is open now using OpenStatusService
        let openNow = OpenStatusService.isOpen(place)
        
        // Calculate and store restaurant type
        calculateAndStoreRestaurantType(for: place)
        
        DispatchQueue.main.async {
            self.isRestaurantOpen = openNow
            // Only auto-present if allowed and not already presented
            if self.allowAutoPresent && !self.isDetailSheetPresented {
                self.isDetailSheetPresented = true
            }
            self.updateCurrentPlaceFullyLoaded()
        }
    }
    
    /// Lazy load external ratings (Google/Mapbox) if they're missing
    private func refreshExternalRatingsIfNeeded(for place: DetailPlace) {
        // Skip if we already have valid ratings (rating > 0 and count exists)
        if let rating = place.rating, rating > 0, place.userRatingsTotal != nil {
            return
        }
        
        // Backend now accepts UUID and handles everything automatically
        let placeId = place.id.uuidString
        
        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let updatedPlace):
                DispatchQueue.main.async {
                    // Only update if this is still the selected place
                    guard self.selectedPlace?.id == place.id else {
                        return
                    }
                    
                    // Update the selected place with fresh ratings
                    var updatedSelectedPlace = self.selectedPlace
                    updatedSelectedPlace?.rating = updatedPlace.rating
                    updatedSelectedPlace?.userRatingsTotal = updatedPlace.userRatingsTotal
                    
                    self.selectedPlace = updatedSelectedPlace
                    
                    // Update Firestore in background (non-blocking)
                    if let placeToUpdate = updatedSelectedPlace {
                        self.updatePlaceInFirestore(placeToUpdate)
                    }
                }
                
            case .failure(let error):
                print("❌ [SelectedPlaceViewModel] Failed to fetch ratings for '\(place.name)': \(error.localizedDescription)")
            }
        }
    }
    
    /// Update place in Firestore with fresh data
    private func updatePlaceInFirestore(_ place: DetailPlace) {
        placeService.updatePlace(place: place) { error in
            if let error = error {
                print("❌ [SelectedPlaceViewModel] Failed to update place in Firestore: \(error.localizedDescription)")
            }
        }
    }

    /// Updates just the description of the currently selected place
    /// Used when polling for AI-generated descriptions
    func updatePlaceDescription(_ description: String) {
        if var place = selectedPlace {
            place.description = description
            selectedPlace = place
        }
    }

    /// Navigate to a place by ID - fetches place details and presents the detail sheet
    /// Single Responsibility: Coordinate place navigation from lightweight place references
    func navigateToPlace(placeId: String, onDismiss: (() -> Void)? = nil) {
        Task {
            guard let detailPlace = try? await PlaceService.shared.fetchPlace(withId: placeId) else { return }
            await MainActor.run {
                self.selectPlaceAndFetchDetails(detailPlace, shouldAnimateMap: true)
                self.isDetailSheetPresented = true
                onDismiss?()
            }
        }
    }
    
    /// Select a place and fetch fresh details from backend
    /// Use this when a user clicks on a place from lists, maps, etc.
    func selectPlaceAndFetchDetails(_ place: DetailPlace, shouldAnimateMap: Bool = true) {
        // Backend now accepts UUID and handles everything automatically
        // Just send the UUID as place_id and "google" as provider
        let placeId = place.id.uuidString

        DispatchQueue.main.async {
            self.isFetchingFreshDetails = true
            self.selectedPlace = place
            self.shouldAnimateMapToPlace = shouldAnimateMap
        }

        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let freshPlace):
                DispatchQueue.main.async {
                    guard self.selectedPlace?.id == place.id else {
                        return
                    }

                    self.isFetchingFreshDetails = false

                    // Merge fresh data while preserving local-only properties (e.g., isCustom)
                    let mergedPlace = self.mergePlaceData(original: place, fresh: freshPlace)
                    
                    self.selectedPlace = mergedPlace
                    
                    // Update Firestore in background
                    self.updatePlaceInFirestore(mergedPlace)
                }
                
            case .failure(let error):
                print("❌ [SelectedPlaceViewModel] fetchPlaceDetails failed for '\(place.name)': \(error.localizedDescription)")
                DispatchQueue.main.async {
                    guard self.selectedPlace?.id == place.id else { return }

                    self.isFetchingFreshDetails = false
                    self.handleSelectedPlaceChange()
                }
            }
        }
    }
    
    /// Sets posts for a place and notifies observers. Optionally updates TikToks.
    private func setPostsAndNotify(placeId: String, posts: [PlacePost], tiktoks: [TikTokVideo]? = nil) {
        placePosts[placeId] = posts
        if let tiktoks = tiktoks {
            placeTikToks[placeId] = tiktoks
        }
        postsUpdateCounter += 1
    }

    private func loadPosts(for place: DetailPlace) {
        let placeId = place.id.uuidString
        DispatchQueue.main.async {
            self.postLoadingStates[placeId] = .loading
        }
        
        // Use Task to handle async call to get current user ID
        Task { @MainActor in
            guard let currentUserId = SupabaseAuthService.shared.currentUserId else {
                print("Error: Current user ID is not available")
                self.postLoadingStates[placeId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
                self.setPostsAndNotify(placeId: placeId, posts: [], tiktoks: [])
                self.updateCurrentPlaceFullyLoaded()
                return
            }
            
            self.loadPostsWithUserId(placeId: placeId, currentUserId: currentUserId)
        }
    }
    
    private func loadPostsWithUserId(placeId: String, currentUserId: String) {
        
        // Fetch posts AND TikToks for the specific place in a single query
        Task {
            do {
                let (posts, tiktoks) = try await postService.fetchPosts(placeId: placeId, latestOnly: false)
                
                await MainActor.run {
                    self.setPostsAndNotify(placeId: placeId, posts: posts, tiktoks: tiktoks)
                    self.postLoadingStates[placeId] = .loaded
                    self.updateCurrentPlaceFullyLoaded()
                }
            } catch {
                await MainActor.run {
                    print("❌ [SelectedPlaceViewModel] Error fetching posts/TikToks for place \(placeId): \(error.localizedDescription)")
                    self.postLoadingStates[placeId] = .error(error)
                    self.setPostsAndNotify(placeId: placeId, posts: [], tiktoks: [])
                    self.updateCurrentPlaceFullyLoaded()
                }
            }
        }
    }
    
    
    // MARK: - Public Methods
    /// Adds a new post to the current place's posts list.
    func addPost(_ post: PlacePost) {
        guard let placeId = selectedPlace?.id.uuidString else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var currentPosts = self.placePosts[placeId] ?? []
            currentPosts.insert(post, at: 0)
            self.setPostsAndNotify(placeId: placeId, posts: currentPosts)
        }
    }
    
    /// Get a post by its ID to access original data
    func getPost(by postId: String) -> PlacePost? {
        // Search through all place posts to find the post with matching ID
        for posts in placePosts.values {
            if let post = posts.first(where: { $0.id == postId }) {
                return post
            }
        }
        return nil
    }
    
    /// Deletes a post from the current place and updates local cache.
    func deletePost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let placeId = selectedPlace?.id.uuidString else {
            completion(.failure(NSError(domain: "SelectedPlaceViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No selected place"])))
            return
        }

        guard placePosts[placeId]?.contains(where: { $0.id == postId }) == true else {
            completion(.failure(NSError(domain: "SelectedPlaceViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post not found in cache"])))
            return
        }

        postService.deletePost(postId: postId) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                DispatchQueue.main.async {
                    var currentPosts = self.placePosts[placeId] ?? []
                    currentPosts.removeAll { $0.id == postId }
                    self.likedPosts.remove(postId)
                    self.setPostsAndNotify(placeId: placeId, posts: currentPosts)
                    completion(.success(()))
                }

            case .failure(let error):
                print("❌ Failed to delete post: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func formattedTimestamp(for post: PlacePost) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: post.timestamp, to: now)
        
        if let minutes = components.minute, minutes < 60 && (components.hour ?? 0) == 0 && (components.day ?? 0) == 0 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if let hours = components.hour, hours < 24 && (components.day ?? 0) == 0 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: post.timestamp)
        }
    }
    
    // Update the method to take userId as parameter
    func checkLikeStatuses(userId: String) {
        guard let placeId = selectedPlace?.id.uuidString,
              let posts = placePosts[placeId] else { return }
        
        // Clear previous likes before checking
        likedPosts.removeAll()
        
        // TODO: Implement like status checking with PostService
    }
    
    // MARK: - Public Accessors
    var posts: [PlacePost] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placePosts[placeId] ?? []
    }

    var tiktokVideos: [TikTokVideo] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeTikToks[placeId] ?? []
    }

    func postLoadingState(forPlaceId placeId: String) -> LoadingState {
        return postLoadingStates[placeId] ?? .idle
    }
    
    func likePost(_ post: PlacePost, userId: String) {
        // TODO: Implement proper like/unlike logic with Supabase
    }

    // Add helper method to check if a post is liked
    func isPostLiked(_ postId: String) -> Bool {
        return likedPosts.contains(postId)
    }

    func createNewPlace(idString: String?, name: String, description: String?, coordinate: CLLocationCoordinate2D, userId: String, profileVM: ProfileViewModel? = nil, detailPlaceVM: DetailPlaceViewModel? = nil) {
        // Create a new place
        var newPlace = DetailPlace()
        if let idString = idString, let uuid = UUID(uuidString: idString) {
            newPlace.id = uuid
        }
        newPlace.name = name
        newPlace.description = description
        newPlace.coordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        newPlace.isCustom = true // Mark as custom place
        
        // Immediately update local state for instant UI feedback
        DispatchQueue.main.async {
            // Add to DetailPlaceViewModel's places dictionary
            if let detailPlaceVM = detailPlaceVM {
                detailPlaceVM.places[newPlace.id.uuidString] = newPlace
                
                // Add current user to placeSavers for this place
                detailPlaceVM.placeSavers[newPlace.id.uuidString] = [userId]
                
                // Trigger annotation calculation for immediate display
                detailPlaceVM.calculateAnnotationPlaces()
                
                // Generate color for the new place
                detailPlaceVM.generateColorForPlace(newPlace.id.uuidString)
            }
            
            // Update ProfileViewModel's myPlaces list
            if let profileVM = profileVM {
                if !profileVM.myPlacesViewModel.myPlaces.contains(newPlace.id.uuidString) {
                    profileVM.myPlacesViewModel.myPlaces.append(newPlace.id.uuidString)
                }
            }
            
            // Send notification to refresh map annotations
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
        }
        
        // Save to database
        Task { @MainActor in
            SupabasePlaceService.shared.testSupabaseConnection { isConnected, error in
                if !isConnected {
                    print("❌ [SelectedPlaceViewModel] Supabase connection failed: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Save to main places collection
                self.placeService.addToAllPlaces(place: newPlace) { error in
                    if let error = error {
                        print("❌ [SelectedPlaceViewModel] Error saving place to main collection: \(error.localizedDescription)")
                    } else {
                        // Save to user's myPlaces collection
                        self.placeService.addToMyPlaces(userId: userId, place: newPlace) { error in
                            if let error = error {
                                print("❌ [SelectedPlaceViewModel] Error saving place to user's collection: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        
        // Update the UI
        selectedPlace = newPlace
        if allowAutoPresent {
            isDetailSheetPresented = true
        }
    }
    
    /// Navigate to map and select a place (for use when navigating from profile views)
    /// This method sets up the place detail FIRST, then dismisses the profile for a smooth transition
    func navigateToMapAndSelectPlace(_ place: DetailPlace, dismissNavigation: @escaping () -> Void) {
        // Set up place selection FIRST (so it's ready when profile dismisses)
        self.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
        self.isDetailSheetPresented = true

        // Dismiss immediately - place detail is already set up and will appear as profile animates away
        dismissNavigation()
    }

    // MARK: - State Preservation (for navigation from place detail)

    /// Preserves current place state before navigating to user profile
    func preserveStateForNavigation() {
        preservedPlaceForNavigation = selectedPlace
    }

    /// Restores place state after returning from user profile navigation
    func restoreStateAfterNavigation() {
        if let preserved = preservedPlaceForNavigation {
            selectedPlace = preserved
            isDetailSheetPresented = true
            preservedPlaceForNavigation = nil
        }
    }

    /// Clears preserved state (e.g., when user navigates elsewhere)
    func clearPreservedState() {
        preservedPlaceForNavigation = nil
    }
    
    // MARK: - Logout Cleanup
    
    /// Clears all user-related cached data - MUST be called on logout to prevent data leakage
    /// Single Responsibility: Only clears this ViewModel's cached state
    func clearAllUserData() {
        print("🗑️ [SelectedPlaceViewModel] Clearing all user data for security")
        
        // Clear selected place state
        selectedPlace = nil
        isDetailSheetPresented = false
        isCurrentPlaceFullyLoaded = false
        
        // Clear all cached data
        placePosts.removeAll()
        placeTikToks.removeAll()
        restaurantTypes.removeAll()
        postLoadingStates.removeAll()
        likedPosts.removeAll()
        
        // Reset UI state
        placeRating = 0
        isRestaurantOpen = false
        allowAutoPresent = true
        shouldAnimateMapToPlace = false
        postsUpdateCounter = 0
        
        print("✅ [SelectedPlaceViewModel] All user data cleared")
    }
}
