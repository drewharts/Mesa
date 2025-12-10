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
    private let reviewService: ReviewService
    private let userService: UserService
    private let placeService: PlaceService
    private let imageService: ImageService
    private let mesaBackendService: MesaBackendService

    private let locationManager: LocationManager
    private weak var detailPlaceViewModel: DetailPlaceViewModel?

    init(locationManager: LocationManager, reviewService: ReviewService, placeService: PlaceService, userService: UserService, imageService: ImageService, mesaBackendService: MesaBackendService = MesaBackendService(), detailPlaceViewModel: DetailPlaceViewModel? = nil) {
        self.locationManager = locationManager
        self.reviewService = reviewService
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
        
        // Load reviews (photos will be loaded automatically by PlacePhotosViewModel)
        loadReviews(for: place)

        // Set Google rating from the place data
        placeRating = place.rating ?? 0

        // Clear previous likes when loading a new place
        likedReviews.removeAll()
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
    /// - `isCustom`: Backend doesn't know about custom places
    /// - `id`: Always keep the original ID
    private func mergePlaceData(original: DetailPlace, fresh: DetailPlace) -> DetailPlace {
        var merged = fresh
        merged.id = original.id
        merged.isCustom = original.isCustom
        return merged
    }
    @Published var isDetailSheetPresented: Bool = false
    @Published var isRestaurantOpen: Bool = false // New property to track open status
    @Published var allowAutoPresent: Bool = true
    @Published var shouldAnimateMapToPlace: Bool = false // Track if map should animate to place location
    @Published private var placeReviews: [String: [any ReviewProtocol]] = [:] // Cache for reviews by placeId
    @Published private var placeTikToks: [String: [TikTokVideo]] = [:] // Cache for TikToks by placeId
    @Published private var restaurantTypes: [String: String] = [:] // Dictionary to store restaurant types by placeId
    
    /// Increments whenever reviews are modified - allows observers to react to review changes
    @Published private(set) var reviewsUpdateCounter: Int = 0
    
    @Published var placeRating: Double = 0
    
    @Published private var reviewLoadingStates: [String: LoadingState] = [:] // Loading states for reviews
    @Published var isCurrentPlaceFullyLoaded: Bool = false
    
    // Add new property to track liked reviews
    @Published private var likedReviews: Set<String> = []

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
        
        let reviewState = reviewLoadingStates[placeId] ?? .idle

        // Consider loaded if reviews are either loaded or in error state
        // (we don't want to wait forever if there's an error)
        // Photos are managed independently by PlacePhotosViewModel
        let reviewsReady: Bool
        switch reviewState {
        case .loaded, .error:
            reviewsReady = true
        case .idle, .loading:
            reviewsReady = false
        }

        // Note: Photos are loaded separately by PlacePhotosViewModel and don't block
        // the main place detail view from loading. Each section shows its own loading state.

        let wasLoaded = isCurrentPlaceFullyLoaded
        isCurrentPlaceFullyLoaded = reviewsReady
        
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
        
        // Compute whether the restaurant is open now
        let openNow = isRestaurantOpenNow(place)
        
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
    
    
    func isRestaurantOpenNow(_ place: DetailPlace) -> Bool {
        guard let openHours = place.openHours, !openHours.isEmpty else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now) // Sunday=1, ..., Saturday=7
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentMinutesSinceWeekStart = ((currentWeekday - 1) * 24 * 60) + (currentHour * 60) + currentMinute

        switch openHours[0] {
        case "always_opened":
            return true
        case "temporarily_closed", "permanently_closed":
            return false
        default:
            for periodString in openHours {
                if !periodString.contains("-") || periodString.hasPrefix("note:") { continue }
                
                let components = periodString.split(separator: "-")
                guard components.count == 2 else { continue }
                
                let openParts = components[0].split(separator: ":")
                let closeParts = components[1].split(separator: ":")
                guard openParts.count == 3, closeParts.count == 3,
                      let openDay = Int(openParts[0]), let openHour = Int(openParts[1]), let openMinute = Int(openParts[2]),
                      let closeDay = Int(closeParts[0]), let closeHour = Int(closeParts[1]), let closeMinute = Int(closeParts[2]) else {
                    continue
                }
                
                // No adjustment needed since OpenPeriod already uses Sunday=1, ..., Saturday=7
                let openMinutes = ((openDay - 1) * 24 * 60) + (openHour * 60) + openMinute
                var closeMinutes = ((closeDay - 1) * 24 * 60) + (closeHour * 60) + closeMinute
                
                if closeMinutes <= openMinutes { closeMinutes += 7 * 24 * 60 } // Handle overnight periods
                if currentMinutesSinceWeekStart >= openMinutes && currentMinutesSinceWeekStart <= closeMinutes {
                    return true
                }
            }
            return false
        }
    }
    
    private func loadReviews(for place: DetailPlace) {
        let placeId = place.id.uuidString
        DispatchQueue.main.async {
            self.reviewLoadingStates[placeId] = .loading
        }
        
        // Use Task to handle async call to get current user ID
        Task { @MainActor in
            guard let currentUserId = await SupabaseAuthService.shared.currentUserId else {
                print("Error: Current user ID is not available")
                self.reviewLoadingStates[placeId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
                self.placeReviews[placeId] = []
                self.updateCurrentPlaceFullyLoaded()
                return
            }
            
            self.loadReviewsWithUserId(placeId: placeId, currentUserId: currentUserId)
        }
    }
    
    private func loadReviewsWithUserId(placeId: String, currentUserId: String) {
        
        // Fetch reviews AND TikToks for the specific place in a single query
        Task {
            do {
                let (reviews, tiktoks) = try await reviewService.fetchPlaceReviews(placeId: placeId, latestOnly: false)
                
                await MainActor.run {
                    self.placeReviews[placeId] = reviews
                    self.placeTikToks[placeId] = tiktoks // Store TikToks
                    self.reviewLoadingStates[placeId] = .loaded
                    
                    // Photos are loaded automatically by PlacePhotosViewModel via observers
                    
                    self.updateCurrentPlaceFullyLoaded()
                }
            } catch {
                await MainActor.run {
                    print("❌ [SelectedPlaceViewModel] Error fetching reviews/TikToks for place \(placeId): \(error.localizedDescription)")
                    self.reviewLoadingStates[placeId] = .error(error)
                    self.placeReviews[placeId] = []
                    self.placeTikToks[placeId] = []
                    
                    self.updateCurrentPlaceFullyLoaded()
                }
            }
        }
    }
    
    
    // MARK: - Public Methods
    func addReview<T: ReviewProtocol>(_ review: T) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var currentReviews = self.placeReviews[placeId] ?? []
            currentReviews.insert(review, at: 0) // Insert at the beginning
            self.placeReviews[placeId] = currentReviews
            
            // Notify observers that reviews have changed (triggers photo reload in PlacePhotosViewModel)
            self.reviewsUpdateCounter += 1
        }
    }
    
    /// Get a review by its ID to access original data
    func getReview(by reviewId: String) -> (any ReviewProtocol)? {
        // Search through all place reviews to find the review with matching ID
        for reviews in placeReviews.values {
            if let review = reviews.first(where: { $0.id == reviewId }) {
                return review
            }
        }
        return nil
    }
    
    func deleteReview(reviewId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let placeId = selectedPlace?.id.uuidString else {
            completion(.failure(NSError(domain: "SelectedPlaceViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No selected place"])))
            return
        }
        
        // Find the review to get the userId
        guard let review = placeReviews[placeId]?.first(where: { $0.id == reviewId }) else {
            completion(.failure(NSError(domain: "SelectedPlaceViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Review not found in cache"])))
            return
        }
        
        reviewService.deleteReview(reviewId: reviewId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                DispatchQueue.main.async {
                    // Remove the review from local cache
                    if var currentReviews = self.placeReviews[placeId] {
                        // Find and remove the review
                        if let index = currentReviews.firstIndex(where: { $0.id == reviewId }) {
                            currentReviews.remove(at: index)
                            self.placeReviews[placeId] = currentReviews
                            
                            // Remove from liked reviews set if it was there
                            self.likedReviews.remove(reviewId)
                        }
                    }
                    completion(.success(()))
                }
                
            case .failure(let error):
                print("❌ Failed to delete review: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func formattedTimestamp<T: ReviewProtocol>(for review: T) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: review.timestamp, to: now)
        
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
            return formatter.string(from: review.timestamp)
        }
    }
    
    // Update the method to take userId as parameter
    func checkLikeStatuses(userId: String) {
        guard let placeId = selectedPlace?.id.uuidString,
              let reviews = placeReviews[placeId] else { return }
        
        // Clear previous likes before checking
        likedReviews.removeAll()
        
        reviews.forEach { review in
            reviewService.hasUserLikedReview(userId: userId, placeId: placeId, reviewId: review.id) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let isLiked):
                        if isLiked {
                            self?.likedReviews.insert(review.id)
                        }
                    case .failure(let error):
                        print("❌ Error checking if review is liked: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Public Accessors
    var reviews: [any ReviewProtocol] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeReviews[placeId] ?? []
    }

    var tiktokVideos: [TikTokVideo] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeTikToks[placeId] ?? []
    }

    func reviewLoadingState(forPlaceId placeId: String) -> LoadingState {
        return reviewLoadingStates[placeId] ?? .idle
    }
    
    func likeReview<T: ReviewProtocol>(_ review: T, userId: String) {
        // TODO: Implement proper like/unlike logic with Supabase
    }

    // Add helper method to check if a review is liked
    func isReviewLiked(_ reviewId: String) -> Bool {
        return likedReviews.contains(reviewId)
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
                if !profileVM.myPlaces.contains(newPlace.id.uuidString) {
                    profileVM.myPlaces.append(newPlace.id.uuidString)
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
    /// This method handles dismissing navigation and then selecting the place with map animation
    func navigateToMapAndSelectPlace(_ place: DetailPlace, dismissNavigation: @escaping () -> Void) {
        // First dismiss any navigation
        dismissNavigation()
        
        // Small delay to ensure navigation is dismissed before selecting place
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // Select place with map animation
            self.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
            self.isDetailSheetPresented = true
        }
    }
}
