//
//  SelectedPlaceViewModel.swift
//  loc
//
//  Parent coordinator ViewModel that composes child ViewModels for place selection.
//  Single Responsibility: Coordinates between child ViewModels and handles cross-cutting concerns.
//
//  Child ViewModels:
//  - selectionState: Manages selection, sheet presentation, navigation
//  - metadata: Manages ratings, restaurant type, open status
//  - creation: Manages custom place creation
//
//  Services:
//  - postsCacheService: Manages posts/TikToks caching, loading, likes (singleton service)
//

import Foundation
import CoreLocation
import UIKit
import Combine

@MainActor
class SelectedPlaceViewModel: ObservableObject {
    // MARK: - Child ViewModels

    let selectionState: PlaceSelectionStateViewModel
    let metadata: PlaceMetadataViewModel
    let creation: PlaceCreationViewModel

    // MARK: - Services

    private let postsCacheService = ServiceContainer.shared.postsCacheService

    // MARK: - Dependencies

    private let locationManager: LocationManager
    private let mesaBackendService: MesaBackendService
    private let placeService: PlaceService
    private weak var detailPlaceViewModel: DetailPlaceViewModel?

    private var cancellables = Set<AnyCancellable>()
    private var serviceCancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initializes the parent ViewModel with dependencies and creates child ViewModels.
    init(
        locationManager: LocationManager,
        postService: PostService,
        placeService: PlaceService,
        userService: UserService,
        imageService: ImageService,
        mesaBackendService: MesaBackendService = .shared,
        detailPlaceViewModel: DetailPlaceViewModel? = nil
    ) {
        self.locationManager = locationManager
        self.mesaBackendService = mesaBackendService
        self.placeService = placeService
        self.detailPlaceViewModel = detailPlaceViewModel

        // Initialize child ViewModels
        self.selectionState = PlaceSelectionStateViewModel()
        self.metadata = PlaceMetadataViewModel(mesaBackendService: mesaBackendService, placeService: placeService)
        self.creation = PlaceCreationViewModel(placeService: placeService)

        setupChildCallbacks()
        setupChildObservers()
        setupServiceObservers()
    }

    // MARK: - Setup

    /// Sets up callbacks from child ViewModels.
    private func setupChildCallbacks() {
        // When a place is selected, load its data
        selectionState.onPlaceSelected = { [weak self] place in
            self?.handlePlaceSelected(place)
        }

        // When fresh details are needed, fetch them
        selectionState.onFetchFreshDetails = { [weak self] place in
            self?.fetchFreshDetailsInBackground(for: place)
        }

        // When a custom place is created, select it
        creation.onPlaceCreated = { [weak self] place in
            self?.handlePlaceCreated(place)
        }
    }

    /// Sets up observers to forward child ViewModel changes to parent.
    private func setupChildObservers() {
        selectionState.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        metadata.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Sets up observers for singleton services.
    private func setupServiceObservers() {
        postsCacheService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &serviceCancellables)
    }

    // MARK: - Convenience Accessors (for backwards compatibility)

    /// The currently selected place.
    var selectedPlace: DetailPlace? {
        get { selectionState.selectedPlace }
        set { selectionState.selectedPlace = newValue }
    }

    /// Whether the detail sheet is presented (bridged to PresentationService).
    var isDetailSheetPresented: Bool {
        get { PresentationService.shared.activeSheet == .placeDetail }
        set {
            if newValue {
                PresentationService.shared.present(.placeDetail)
            } else if PresentationService.shared.activeSheet == .placeDetail {
                PresentationService.shared.dismiss()
            }
            // Also update child state for internal consistency
            selectionState.isDetailSheetPresented = newValue
        }
    }

    /// Whether to allow auto-presentation.
    var allowAutoPresent: Bool {
        get { selectionState.allowAutoPresent }
        set { selectionState.allowAutoPresent = newValue }
    }

    /// Whether map should animate to place.
    var shouldAnimateMapToPlace: Bool {
        get { selectionState.shouldAnimateMapToPlace }
        set { selectionState.shouldAnimateMapToPlace = newValue }
    }

    /// Preserved place for navigation.
    var preservedPlaceForNavigation: DetailPlace? {
        get { selectionState.preservedPlaceForNavigation }
        set { selectionState.preservedPlaceForNavigation = newValue }
    }

    /// The Google rating for the current place.
    var placeRating: Double {
        get { metadata.placeRating }
        set { metadata.placeRating = newValue }
    }

    /// Whether the current place is open.
    var isRestaurantOpen: Bool {
        metadata.isRestaurantOpen
    }

    /// Whether the current place is fully loaded.
    var isCurrentPlaceFullyLoaded: Bool {
        guard let placeId = selectedPlace?.id.uuidString else { return false }
        return postsCacheService.isFullyLoaded(forPlaceId: placeId)
    }

    /// Posts for the currently selected place.
    var posts: [PlacePost] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return postsCacheService.posts(forPlaceId: placeId)
    }

    /// TikToks for the currently selected place.
    var tiktokVideos: [TikTokVideo] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return postsCacheService.tiktoks(forPlaceId: placeId)
    }

    // MARK: - Public Methods (Delegation to Children)

    /// Selects a place that already has complete data.
    func selectPlace(_ place: DetailPlace, shouldAnimateMap: Bool = true) {
        selectionState.selectPlace(place, shouldAnimateMap: shouldAnimateMap)
    }

    /// Selects a place and fetches fresh details.
    func selectPlaceAndFetchDetails(_ place: DetailPlace, shouldAnimateMap: Bool = true) {
        selectionState.selectPlaceAndFetchDetails(place, shouldAnimateMap: shouldAnimateMap)
    }

    /// Navigates to a place by ID.
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

    /// Navigates to map and selects a place.
    func navigateToMapAndSelectPlace(_ place: DetailPlace, dismissNavigation: @escaping () -> Void) {
        self.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
        self.isDetailSheetPresented = true
        dismissNavigation()
    }

    /// Updates just the description of the currently selected place.
    func updatePlaceDescription(_ description: String) {
        if var place = selectedPlace {
            place.description = description
            selectionState.updatePlaceDetails(place)
        }
    }

    /// Returns the restaurant type for a place.
    func getRestaurantType(for placeId: String) -> String? {
        metadata.getRestaurantType(forPlaceId: placeId)
    }

    /// Returns the loading state for posts.
    func postLoadingState(forPlaceId placeId: String) -> PlacePostsCacheService.LoadingState {
        postsCacheService.loadingState(forPlaceId: placeId)
    }

    /// Formats a post's timestamp.
    func formattedTimestamp(for post: PlacePost) -> String {
        postsCacheService.formattedTimestamp(for: post)
    }

    /// Returns whether a post is liked.
    func isPostLiked(_ postId: String) -> Bool {
        postsCacheService.isPostLiked(postId)
    }

    /// Gets a post by ID.
    func getPost(by postId: String) -> PlacePost? {
        postsCacheService.getPost(by: postId)
    }

    /// Adds a post to the current place.
    func addPost(_ post: PlacePost) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        postsCacheService.addPost(post, forPlaceId: placeId)
    }

    /// Deletes a post from the current place.
    func deletePost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let placeId = selectedPlace?.id.uuidString else {
            completion(.failure(NSError(domain: "SelectedPlaceViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No selected place"])))
            return
        }
        postsCacheService.deletePost(postId: postId, forPlaceId: placeId, completion: completion)
    }

    /// Checks like statuses for posts.
    func checkLikeStatuses(userId: String) {
        // TODO: Implement with PostService
    }

    /// Likes a post.
    func likePost(_ post: PlacePost, userId: String) {
        // TODO: Implement with Supabase
    }

    /// Creates a new custom place.
    func createNewPlace(
        idString: String?,
        name: String,
        description: String?,
        coordinate: CLLocationCoordinate2D,
        userId: String,
        profileVM: ProfileViewModel? = nil,
        detailPlaceVM: DetailPlaceViewModel? = nil
    ) {
        creation.createNewPlace(
            idString: idString,
            name: name,
            description: description,
            coordinate: coordinate,
            userId: userId,
            profileVM: profileVM,
            detailPlaceVM: detailPlaceVM
        )
    }

    // MARK: - State Preservation (Delegation)

    /// Preserves current place state before navigation.
    func preserveStateForNavigation() {
        selectionState.preserveStateForNavigation()
    }

    /// Restores place state after navigation.
    func restoreStateAfterNavigation() {
        selectionState.restoreStateAfterNavigation()
    }

    /// Clears preserved state.
    func clearPreservedState() {
        selectionState.clearPreservedState()
    }

    // MARK: - Cleanup

    /// Clears all user-related cached data - MUST be called on logout.
    func clearAllUserData() {
        print("🗑️ [SelectedPlaceViewModel] Clearing all user data for security")

        selectionState.clearAllState()
        postsCacheService.clearAllData()
        metadata.clearAllData()

        print("✅ [SelectedPlaceViewModel] All user data cleared")
    }

    // MARK: - Private Methods

    /// Handles when a place is selected.
    private func handlePlaceSelected(_ place: DetailPlace) {
        let currentCoordinate = locationManager.currentLocation?.coordinate

        if placeNeedsCompleteDetails(place) && !selectionState.isFetchingFreshDetails {
            fetchCompletePlaceDetails(for: place, currentLocation: currentCoordinate)
        } else {
            continueWithPlaceSetup(place: place, currentLocation: currentCoordinate)
        }
    }

    /// Handles when a custom place is created.
    private func handlePlaceCreated(_ place: DetailPlace) {
        selectionState.selectedPlace = place
        if allowAutoPresent {
            selectionState.forcePresentDetailSheet()
        }
    }

    /// Checks if a place needs complete details.
    private func placeNeedsCompleteDetails(_ place: DetailPlace) -> Bool {
        let missingRating = place.rating == nil
        let missingReviewCount = place.userRatingsTotal == nil
        let missingCategories = place.categories == nil || place.categories?.isEmpty == true
        return missingRating || missingReviewCount || missingCategories
    }

    /// Continues with place setup after data is ready.
    private func continueWithPlaceSetup(place: DetailPlace, currentLocation: CLLocationCoordinate2D?) {
        metadata.computeMetadata(for: place)
        loadPostsIfReady(for: place)
        selectionState.presentDetailSheet()
    }

    /// Loads posts for the place if it has a real Supabase UUID (skips placeholder IDs from search).
    private func loadPostsIfReady(for place: DetailPlace) {
        guard !place.hasPlaceholderID else { return }
        postsCacheService.clearLikedPosts()
        postsCacheService.loadPosts(forPlaceId: place.id.uuidString)
    }

    /// Fetches complete place details when missing.
    private func fetchCompletePlaceDetails(for place: DetailPlace, currentLocation: CLLocationCoordinate2D?) {
        // Use googlePlaceId for external places, fall back to UUID for custom places
        let placeId = place.googlePlaceId ?? place.id.uuidString

        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google") { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let freshPlace):
                    let mergedPlace = self.mergePlaceData(original: place, fresh: freshPlace)
                    self.selectionState.updatePlaceDetails(mergedPlace)
                    self.continueWithPlaceSetup(place: mergedPlace, currentLocation: currentLocation)

                case .failure:
                    print("❌ [SelectedPlaceViewModel] Failed to get complete details, continuing with current data")
                    self.continueWithPlaceSetup(place: place, currentLocation: currentLocation)
                }
            }
        }
    }

    /// Fetches fresh place details in background and loads posts once the real UUID is resolved.
    private func fetchFreshDetailsInBackground(for place: DetailPlace) {
        // Use googlePlaceId for external places, fall back to UUID for custom places
        let placeId = place.googlePlaceId ?? place.id.uuidString

        Task {
            do {
                let freshPlace = try await mesaBackendService.fetchPlaceDetails(placeId: placeId)

                await MainActor.run {
                    guard self.selectedPlace?.id == place.id else { return }

                    self.selectionState.markFetchComplete()

                    let mergedPlace = self.mergePlaceData(original: place, fresh: freshPlace)
                    self.selectionState.updatePlaceDetails(mergedPlace)

                    self.loadPostsIfReady(for: mergedPlace)

                    // If original had invalid coordinates but fresh has valid ones, animate now
                    let originalWasInvalid = place.coordinate == nil || !place.coordinate!.isValidForNavigation
                    let freshIsValid = mergedPlace.coordinate?.isValidForNavigation == true
                    if originalWasInvalid && freshIsValid {
                        self.selectionState.shouldAnimateMapToPlace = true
                    }

                    // Update database in background
                    self.updatePlaceInDatabase(mergedPlace)
                }
            } catch {
                print("❌ [SelectedPlaceViewModel] fetchPlaceDetails failed for '\(place.name)': \(error.localizedDescription)")

                await MainActor.run {
                    guard self.selectedPlace?.id == place.id else { return }
                    self.selectionState.markFetchComplete()
                }
            }
        }
    }

    /// Merges fresh backend data with original place, preserving local-only properties.
    /// Uses fresh.id (the Supabase UUID from the backend) instead of original.id,
    /// because places created from search have a locally-generated random UUID that
    /// won't match the Supabase UUID used to store external reviews.
    private func mergePlaceData(original: DetailPlace, fresh: DetailPlace) -> DetailPlace {
        var merged = fresh
        // Keep fresh.id — it's the authoritative Supabase UUID from the backend.
        // original.id may be a random UUID (generated when googlePlaceId fails UUID parsing).
        merged.isCustom = original.isCustom

        // Use original coordinate only if valid; otherwise use fresh coordinate
        if let originalCoord = original.coordinate, originalCoord.isValidForNavigation {
            merged.coordinate = original.coordinate
        }
        // If original is invalid/nil, keep fresh.coordinate (already in merged)

        if merged.openHours == nil || merged.openHours?.isEmpty == true {
            merged.openHours = original.openHours
        }

        return merged
    }

    /// Updates place in database.
    private func updatePlaceInDatabase(_ place: DetailPlace) {
        placeService.updatePlace(place: place) { error in
            if let error = error {
                print("❌ [SelectedPlaceViewModel] Failed to update place in database: \(error.localizedDescription)")
            }
        }
    }
}
