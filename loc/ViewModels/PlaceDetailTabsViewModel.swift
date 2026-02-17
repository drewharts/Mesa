//
//  PlaceDetailTabsViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Proper MVVM implementation - One View, One ViewModel
//  Uses data-driven approach: View calls setPlace/setPosts instead of ViewModel observing other ViewModels
//

import Foundation
import SwiftUI
import CoreLocation
import Combine

// MARK: - Tab Type
enum DetailTab {
    case about
    case reviews
}

@MainActor
class PlaceDetailTabsViewModel: ObservableObject {
    // MARK: - Dependencies (Services from ServiceContainer)
    private let placeService: PlaceService
    private let postService: PostService
    private let userService: UserService
    private let notificationManager: NotificationManager
    private let placeShareService: PlaceShareService
    private let userSession: UserSession
    private let placeListService = PlaceListService.shared
    private let postsCacheService = ServiceContainer.shared.postsCacheService
    private let placeRepository = PlaceRepository.shared

    // MARK: - Callbacks (replaces ViewModel observations)
    /// Checks if a place is in the user's favorites (injected from ProfileViewModel)
    var isFavoriteCheck: ((String) -> Bool)?

    /// Called when manual refresh fetches updated place metadata from the backend.
    var onPlaceMetadataRefreshed: ((DetailPlace) -> Void)?

    // MARK: - Child ViewModels
    let aboutTabViewModel: AboutTabViewModel
    let notesTabViewModel: NotesTabViewModel
    let postsViewModel: PlacePostsViewModel
    let placePhotosViewModel: PlacePhotosViewModel  // Exposed for data-driven updates
    let travelTimeViewModel: TravelTimeViewModel
    let openStatusViewModel: OpenStatusViewModel
    var placeSaversViewModel: PlaceSaversViewModel

    // MARK: - Published Properties (What the View Needs)
    @Published var placeName: String = "Loading..."
    @Published var restaurantType: String?
    @Published var isCustomPlace: Bool = false
    @Published var placeRating: Double = 0.0
    @Published var hasPosts: Bool = false
    @Published var postCount: Int = 0
    @Published var selectedTab: DetailTab = .about
    @Published var currentPlace: DetailPlace?

    // Forwarded from PlaceSaversViewModel (enables view re-render when savers change)
    @Published var showSaversIndicator: Bool = false
    @Published var saverCount: Int = 0

    // Forwarded from OpenStatusViewModel (enables view re-render when status changes)
    @Published var openStatus: OpenStatus = .unknown

    // MARK: - Place Actions State
    /// Whether the current place is saved in any of the user's lists or favorites
    @Published var isPlaceInList: Bool = false

    /// Whether a manual refresh is currently in progress
    @Published var isRefreshing: Bool = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization (Data-Driven - No ViewModel Dependencies in Child ViewModels)
    /// Creates PlaceDetailTabsViewModel with minimal ViewModel dependencies
    /// Child ViewModels are fully refactored with data-driven approach
    init(userSession: UserSession,
         profileVM: ProfileViewModel,
         detailPlaceViewModel: DetailPlaceViewModel,
         selectedPlaceVM: SelectedPlaceViewModel) {
        // Get services from ServiceContainer
        self.placeService = ServiceContainer.shared.placeService
        self.postService = ServiceContainer.shared.postService
        self.userService = ServiceContainer.shared.userService
        self.notificationManager = ServiceContainer.shared.notificationManager
        self.placeShareService = ServiceContainer.shared.placeShareService
        self.userSession = userSession

        // Create child ViewModels (all fully refactored - no ViewModel dependencies)
        let tikTokVM = TikTokVideosViewModel()

        // Wire up TikTok callback to refresh external places when video is deleted
        tikTokVM.onVideoDeleted = { [weak profileVM] in
            Task {
                await profileVM?.fetchUserExternalPlaces()
            }
        }

        // PlacePhotosViewModel - fully refactored (no ViewModel dependencies)
        let photosVM = PlacePhotosViewModel()

        let customPlaceCreatorVM = CustomPlaceCreatorViewModel(
            placeService: ServiceContainer.shared.placeService
        )

        // NotesTabViewModel - fully refactored (no ViewModel dependencies)
        self.notesTabViewModel = NotesTabViewModel(userSession: userSession)

        // Wire up notes callbacks to sync with ProfileViewModel
        self.notesTabViewModel.onNoteSaved = { [weak profileVM] placeId, note in
            profileVM?.notesViewModel.placeNotes[placeId] = note
        }
        self.notesTabViewModel.onNoteDeleted = { [weak profileVM] placeId in
            profileVM?.notesViewModel.placeNotes.removeValue(forKey: placeId)
        }

        // Store photosVM for data-driven updates
        self.placePhotosViewModel = photosVM

        // AboutTabViewModel - fully refactored (no ViewModel dependencies)
        self.aboutTabViewModel = AboutTabViewModel(
            tikTokVideosViewModel: tikTokVM,
            placePhotosViewModel: photosVM,
            customPlaceCreatorViewModel: customPlaceCreatorVM,
            notesViewModel: self.notesTabViewModel
        )

        // Wire up description callback to update selected place
        self.aboutTabViewModel.onDescriptionUpdated = { [weak selectedPlaceVM] description in
            selectedPlaceVM?.updatePlaceDescription(description)
        }

        // PlacePostsViewModel - fully refactored (no ViewModel dependencies)
        self.postsViewModel = PlacePostsViewModel(
            photosViewModel: photosVM,
            notificationManager: ServiceContainer.shared.notificationManager,
            userSession: userSession
        )

        // Wire up posts callbacks
        self.postsViewModel.onCheckLikeStatuses = { [weak selectedPlaceVM] userId in
            selectedPlaceVM?.checkLikeStatuses(userId: userId)
        }

        // Child VMs with no ViewModel dependencies (fully refactored)
        self.travelTimeViewModel = TravelTimeViewModel()
        self.openStatusViewModel = OpenStatusViewModel()

        self.placeSaversViewModel = PlaceSaversViewModel(
            userService: ServiceContainer.shared.userService,
            userSession: userSession
        )

        // Wire up savers callback to sync with DetailPlaceViewModel
        self.placeSaversViewModel.onSaversUpdated = { [weak detailPlaceViewModel] placeId, saverIds in
            detailPlaceViewModel?.placeSavers[placeId] = saverIds
        }

        // Wire up metadata refresh callback to update SelectedPlaceViewModel
        self.onPlaceMetadataRefreshed = { [weak selectedPlaceVM] refreshedPlace in
            selectedPlaceVM?.selectionState.updatePlaceDetails(refreshedPlace)
        }

        setupObservers()
        setupPostsCacheObserver()
    }

    // MARK: - Setup
    private func setupObservers() {
        // Observe notification highlights (this is a service, not a ViewModel)
        notificationManager.$highlightedReviewId
            .sink { [weak self] postId in
                if postId != nil {
                    self?.selectedTab = .reviews
                }
            }
            .store(in: &cancellables)

        // Forward PlaceSaversViewModel state to trigger view updates
        // This is necessary because child VM changes don't automatically trigger parent view re-render
        Publishers.CombineLatest(
            placeSaversViewModel.$totalGlobalSaveCount,
            placeSaversViewModel.$currentUserSaved
        )
        .sink { [weak self] globalCount, currentUserSaved in
            self?.saverCount = globalCount
            // Only show indicator if OTHER people (besides current user) saved this place
            // If current user saved, need at least 2 total saves to show indicator
            self?.showSaversIndicator = currentUserSaved ? globalCount > 1 : globalCount > 0
        }
        .store(in: &cancellables)

        // Forward OpenStatusViewModel state to trigger view updates
        openStatusViewModel.$status
            .sink { [weak self] status in
                self?.openStatus = status
            }
            .store(in: &cancellables)
    }

    /// Sets up reactive subscription to posts cache - triggers when posts for current place change.
    private func setupPostsCacheObserver() {
        // Combine currentPlace with postsCache - fires when either changes
        // This is the proper reactive pattern: subscribe to actual data, not manual triggers
        Publishers.CombineLatest3(
            $currentPlace.map { $0?.id.uuidString },
            postsCacheService.$postsCache,
            postsCacheService.$loadingStates
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] placeId, postsCache, loadingStates in
            self?.handlePostsDataChanged(
                placeId: placeId,
                postsCache: postsCache,
                loadingStates: loadingStates
            )
        }
        .store(in: &cancellables)

        // Separate subscription for TikToks cache
        Publishers.CombineLatest(
            $currentPlace.map { $0?.id.uuidString },
            postsCacheService.$tiktoksCache
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] placeId, tiktoksCache in
            guard let placeId = placeId else { return }
            let tiktoks = tiktoksCache[placeId] ?? []
            self?.aboutTabViewModel.tikTokVideosViewModel.setPlaceVideos(tiktoks)
        }
        .store(in: &cancellables)
    }

    /// Handles posts data changes from the reactive subscription.
    private func handlePostsDataChanged(
        placeId: String?,
        postsCache: [String: [PlacePost]],
        loadingStates: [String: PlacePostsCacheService.LoadingState]
    ) {
        guard let placeId = placeId else { return }

        let posts = postsCache[placeId] ?? []
        let loadingState = loadingStates[placeId] ?? .idle

        self.hasPosts = !posts.isEmpty
        self.postCount = posts.count

        let postsFinished: Bool
        switch loadingState {
        case .loaded, .error:
            postsFinished = true
        default:
            postsFinished = false
        }
        placePhotosViewModel.setPostsLoadingFinished(postsFinished)
        placePhotosViewModel.setPosts(posts)
        postsViewModel.setPosts(posts)
        aboutTabViewModel.wouldReturnStats = WouldReturnStats.from(posts: posts)
        postsViewModel.setLoadingState(mapLoadingState(loadingState))

        if posts.isEmpty && selectedTab == .reviews {
            selectedTab = .about
        }
    }

    /// Maps PlacePostsCacheService loading state to PlacePostsViewModel loading state.
    private func mapLoadingState(_ state: PlacePostsCacheService.LoadingState) -> PlacePostsViewModel.LoadingState {
        switch state {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded:
            return .loaded
        case .error(let error):
            return .error(error)
        }
    }

    // MARK: - Data-Driven Updates (Called by View via .onChange)

    /// Updates place metadata without resetting child ViewModel state.
    /// Called when the same place gets updated with fresh backend data (e.g. placeholder → real UUID).
    func refreshPlaceData(_ place: DetailPlace?) {
        handlePlaceChanged(place)
        openStatusViewModel.setPlace(place)
        aboutTabViewModel.setPlace(place)

        // If photos weren't loaded yet (placeholder UUID was skipped), load now with the real UUID
        if let place = place, placePhotosViewModel.externalPhotoItems.isEmpty,
           !place.hasPlaceholderID {
            placePhotosViewModel.setPlace(place)
            placeSaversViewModel.setPlace(place.id.uuidString)
        }
    }

    /// Called by View when selected place changes.
    func setPlace(_ place: DetailPlace?) {
        // Setting currentPlace triggers the reactive subscription automatically
        handlePlaceChanged(place)

        // Update all child ViewModels with new place
        travelTimeViewModel.setPlace(place)
        openStatusViewModel.setPlace(place)
        placeSaversViewModel.setPlace(place?.id.uuidString)
        notesTabViewModel.setPlace(place)
        placePhotosViewModel.setPlace(place)
        aboutTabViewModel.setPlace(place)
        postsViewModel.setPlace(place)

        // Check place list membership
        Task {
            await checkPlaceListMembership(place: place)
        }
    }

    /// Called by View when posts/rating change (legacy method for backward compatibility).
    /// Posts are now primarily synced via PlacePostsCacheService subscription.
    func setPosts(_ posts: [PlacePost], rating: Double) {
        self.placeRating = rating
        self.hasPosts = !posts.isEmpty
        self.postCount = posts.count

        // Update child ViewModels with posts data
        placePhotosViewModel.setPosts(posts)
        postsViewModel.setPosts(posts)
        aboutTabViewModel.wouldReturnStats = WouldReturnStats.from(posts: posts)

        // Set default tab based on posts
        if posts.isEmpty && selectedTab == .reviews {
            selectedTab = .about
        }
    }

    /// Called when the place rating changes.
    func setRating(_ rating: Double) {
        self.placeRating = rating
    }

    /// Called by View when TikTok videos change.
    func setTikTokVideos(placeVideos: [TikTokVideo], userVideos: [TikTokVideo]) {
        aboutTabViewModel.tikTokVideosViewModel.setPlaceVideos(placeVideos)
        aboutTabViewModel.tikTokVideosViewModel.setUserVideos(userVideos)
    }

    /// Called by View when post loading state changes.
    func setPostLoadingState(_ state: PlacePostsViewModel.LoadingState) {
        postsViewModel.setLoadingState(state)
    }

    /// Check if the current place is saved in any of the user's lists OR favorites.
    private func checkPlaceListMembership(place: DetailPlace?) async {
        guard let place = place, let userId = userSession.currentUserId else {
            isPlaceInList = false
            return
        }

        let placeId = place.id.uuidString

        // Check favorites via callback (synchronous, client-side)
        let isFavorite = isFavoriteCheck?(placeId) ?? false

        do {
            let isSaved = try await placeListService.isPlaceInAnyUserList(
                userId: userId,
                placeId: placeId
            )
            isPlaceInList = isSaved || isFavorite
        } catch {
            print("❌ [PlaceDetailTabsVM] Error checking place list membership: \(error)")
            isPlaceInList = isFavorite
        }
    }

    /// Triggers a full refresh of place data (metadata, posts, photos, savers, list membership) and sets isRefreshing until complete.
    func manualRefresh() {
        guard let place = currentPlace else { return }
        isRefreshing = true
        let placeId = place.id.uuidString
        postsCacheService.loadPosts(forPlaceId: placeId)
        placePhotosViewModel.setPlace(place)
        placeSaversViewModel.setPlace(placeId)
        Task {
            await checkPlaceListMembership(place: place)
        }
        refreshPlaceMetadata(for: place)
    }

    /// Re-fetches place metadata from the backend, propagates the update, and clears the isRefreshing flag when complete.
    private func refreshPlaceMetadata(for place: DetailPlace) {
        guard place.isCustom != true else {
            isRefreshing = false
            return
        }
        Task {
            defer { isRefreshing = false }
            do {
                let refreshed = try await placeRepository.resolvePlace(
                    googlePlaceId: place.googlePlaceId,
                    fallbackId: place.id.uuidString,
                    existingPlace: place
                )
                self.refreshPlaceData(refreshed)
                self.onPlaceMetadataRefreshed?(refreshed)
            } catch {
                print("⚠️ [PlaceDetailTabsVM] Metadata refresh failed: \(error.localizedDescription)")
            }
        }
    }

    /// Public method to refresh list membership state (call after saving to list)
    func refreshPlaceListMembership() {
        Task {
            await checkPlaceListMembership(place: currentPlace)
        }
    }

    /// Configure savers VM with navigation dependency (call from View)
    func configureSaversViewModel(userProfileNavigationViewModel: UserProfileNavigationViewModel) {
        placeSaversViewModel.configure(userProfileNavigationViewModel: userProfileNavigationViewModel)
    }
    
    private func handlePlaceChanged(_ place: DetailPlace?) {
        currentPlace = place
        placeName = place?.name ?? "Loading..."
        isCustomPlace = place?.isCustom == true

        if let place = place {
            // For custom places, view shows "Created by [photo]" instead of type
            // Still compute type in case we want to show both in the future
            restaurantType = getRestaurantType(for: place)
        } else {
            restaurantType = nil
        }
    }
    
    // Travel time management delegated to TravelTimeViewModel
    // MARK: - Actions (What the View Can Trigger)
    func selectTab(_ tab: DetailTab) {
        selectedTab = tab
    }
    
    /// Shares the current place using the system share sheet
    func sharePlace() {
        guard let place = currentPlace else { return }
        placeShareService.sharePlace(place)
    }
    
    func openGoogleMaps() {
        guard let place = currentPlace else { return }
        let name = place.name
        
        let query: String
        if let address = place.address {
            query = "\(name), \(address)"
        } else if let latitude = place.coordinate?.latitude,
                  let longitude = place.coordinate?.longitude {
            query = "\(name) @\(latitude),\(longitude)"
        } else {
            query = name
        }
        
        openGoogleMapsWithPlace(query: query)
    }
    
    func onAppear() {
        // Load review photos for about section (handled by PlacePhotosViewModel)
        // PlacePhotosViewModel automatically loads review photos when place changes
    }
    
    // MARK: - Private Helpers
    private func getRestaurantType(for place: DetailPlace) -> String? {
        guard let placeTypes = place.categories, !placeTypes.isEmpty else {
            return PlaceTypes.defaultType
        }
        
        let placeTypesCopy = Array(placeTypes)
        let recognizedTypesCopy = Array(PlaceTypes.recognizedTypes)
        
        // Generic terms to skip in first pass
        let genericTerms = [
            "Restaurant", "Cafe", "Bar", "Place",
            "Point of Interest", "Point Of Interest", "Point_of_Interest",
            "POI", "Establishment", "Store", "Business", "Location",
            "Venue", "Site", "Spot", "Destination"
        ]
        
        // First pass: Look for specific cuisine types
        for recognizedType in recognizedTypesCopy {
            let normalizedRecognizedType = recognizedType.lowercased()
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: ".", with: " ")
            
            let isGenericTerm = genericTerms.contains { genericTerm in
                let normalizedGenericTerm = genericTerm.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                return normalizedRecognizedType == normalizedGenericTerm
            }
            
            if isGenericTerm { continue }
            
            guard !recognizedType.isEmpty else { continue }
            
            if placeTypesCopy.contains(where: { placeType in
                guard !placeType.isEmpty else { return false }
                
                let normalizedPlaceType = placeType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                let normalizedRecognizedType = recognizedType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                guard !normalizedPlaceType.isEmpty && !normalizedRecognizedType.isEmpty else {
                    return false
                }
                
                return normalizedPlaceType.contains(normalizedRecognizedType)
            }) {
                return recognizedType
            }
        }
        
        // Second pass: Look for generic terms if no specific type found
        for genericTerm in genericTerms {
            if placeTypesCopy.contains(where: { placeType in
                guard !placeType.isEmpty else { return false }
                
                let normalizedPlaceType = placeType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                let normalizedGenericTerm = genericTerm.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                guard !normalizedPlaceType.isEmpty && !normalizedGenericTerm.isEmpty else {
                    return false
                }
                
                return normalizedPlaceType.contains(normalizedGenericTerm)
            }) {
                return genericTerm
            }
        }
        
        return PlaceTypes.defaultType
    }
    
    private func openGoogleMapsWithPlace(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let googleMapsURL = URL(string: "comgooglemaps://?q=\(encodedQuery)") else { return }
        let fallbackURL = URL(string: "https://maps.google.com/?q=\(encodedQuery)")!
        
        if UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.open(fallbackURL, options: [:], completionHandler: nil)
        }
    }
}

