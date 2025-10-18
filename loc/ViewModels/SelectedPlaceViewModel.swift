//
//  SelectedPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//

import Foundation
import MapboxSearch
import CoreLocation
import UIKit

// MARK: - Services
// Note: MesaBackendService import should be available via project imports


class SelectedPlaceViewModel: ObservableObject {
    private let reviewService: ReviewService
    private let userService: UserService
    private let placeService: PlaceService
    private let imageService: ImageService
    private let mesaBackendService: MesaBackendService

    private let locationManager: LocationManager

    init(locationManager: LocationManager, reviewService: ReviewService, placeService: PlaceService, userService: UserService, imageService: ImageService, mesaBackendService: MesaBackendService = MesaBackendService()) {
        self.locationManager = locationManager
        self.reviewService = reviewService
        self.placeService = placeService
        self.userService = userService
        self.imageService = imageService
        self.mesaBackendService = mesaBackendService
    }

    private var isUpdatingPlaceDetails = false

    @Published var selectedPlace: DetailPlace? {
        didSet {
            print("🔄 [SelectedPlaceViewModel] selectedPlace didSet triggered for: \(selectedPlace?.name ?? "nil")")
            
            // Prevent infinite loop when updating place details
            guard !isUpdatingPlaceDetails else {
                print("⚠️ [SelectedPlaceViewModel] Skipping didSet - isUpdatingPlaceDetails = true")
                return
            }

            if let place = selectedPlace,
               let currentLocation = locationManager.currentLocation {
                
                print("📍 [SelectedPlaceViewModel] Place and location available")
                print("   - Rating: \(place.rating ?? 0)")
                print("   - Categories: \(place.categories?.count ?? 0)")
                print("   - UserRatingsTotal: \(place.userRatingsTotal ?? 0)")

                // Check if place has complete details (rating, reviews count, categories)
                // If not, fetch complete details from backend
                if place.rating == nil || place.userRatingsTotal == nil || place.categories == nil || place.categories?.isEmpty == true {
                    print("⚠️ [SelectedPlaceViewModel] Place missing details, fetching complete details...")
                    fetchCompletePlaceDetails(for: place) { [weak self] updatedPlace in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                            if let updatedPlace = updatedPlace {
                                print("✅ [SelectedPlaceViewModel] Got complete details, updating place")
                                // Update the selected place with complete data (without triggering didSet)
                                self.isUpdatingPlaceDetails = true
                                self.selectedPlace = updatedPlace
                                self.isUpdatingPlaceDetails = false
                                
                                // Since we bypassed didSet, manually trigger the setup
                                print("🎬 [SelectedPlaceViewModel] Manually calling continueWithPlaceSetup after bypass")
                                self.continueWithPlaceSetup(place: updatedPlace, currentLocation: currentLocation.coordinate)
                            } else {
                                print("❌ [SelectedPlaceViewModel] Failed to get complete details, continuing with current data")
                                // If fetch failed, continue with current data
                                self.continueWithPlaceSetup(place: place, currentLocation: currentLocation.coordinate)
                            }
                        }
                    }
                } else {
                    print("✅ [SelectedPlaceViewModel] Place has complete details, continuing with setup")
                    continueWithPlaceSetup(place: place, currentLocation: currentLocation.coordinate)
                }
            } else {
                if selectedPlace == nil {
                    print("⚠️ [SelectedPlaceViewModel] selectedPlace is nil, skipping setup")
                } else {
                    print("⚠️ [SelectedPlaceViewModel] currentLocation is nil, skipping setup")
                }
            }
        }
    }

    private func continueWithPlaceSetup(place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        print("🎬 [SelectedPlaceViewModel] continueWithPlaceSetup for '\(place.name)'")
        loadData(for: place, currentLocation: currentLocation)
        loadReviews(for: place)

        // Set Google rating from the place data
        placeRating = place.rating ?? 0

        // Reset photo loading state for new place
        print("🔄 [SelectedPlaceViewModel] Resetting photo loading state")
        resetPhotoLoading()
        print("📸 [SelectedPlaceViewModel] Starting to get place photos")
        getPlacePhotos(for: place)
        
        // Load review photos for about section
        print("📸 [SelectedPlaceViewModel] Starting to load review photos for about section")
        loadReviewPhotosForAbout(for: place)

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
    @Published var isDetailSheetPresented: Bool = false
    @Published var isRestaurantOpen: Bool = false // New property to track open status
    @Published var allowAutoPresent: Bool = true
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache for place-level photos by placeId
    @Published private var placeReviews: [String: [any ReviewProtocol]] = [:] // Cache for reviews by placeId
    @Published private var reviewPhotos: [String: [UIImage]] = [:] // Cache for review photos by reviewId
    @Published private var userProfilePhotos: [String: UIImage] = [:] // Cache for profile photos by userId
    @Published private var restaurantTypes: [String: String] = [:] // Dictionary to store restaurant types by placeId
    @Published private var reviewPhotosForAbout: [String: [UIImage]] = [:] // Cache for review photos in about section by placeId
    
    @Published var placeRating: Double = 0
    
    @Published private var photoLoadingStates: [String: LoadingState] = [:] // Loading states for place photos
    @Published private var reviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for review photos
    @Published private var profilePhotoLoadingStates: [String: LoadingState] = [:] // Loading states for profile photos
    @Published private var reviewLoadingStates: [String: LoadingState] = [:] // Loading states for reviews
    @Published private var reviewPhotosForAboutLoadingStates: [String: LoadingState] = [:] // Loading states for review photos in about section
    @Published var isCurrentPlaceFullyLoaded: Bool = false

    // Add pagination properties for photos
    @Published private var photoPageLimit = 9
    @Published private var lastPhotoDocument: Any? // Replaced DocumentSnapshot for Supabase migration
    @Published private var allPhotosLoaded = false
    
    // Add new property to track liked reviews
    @Published private var likedReviews: Set<String> = []


    // MARK: - Comment Management Properties
    private var placeReviewComments: [String: [Comment]] = [:] // reviewId -> comments
    private var commentLoadingStates: [String: LoadingState] = [:] // reviewId -> loading state
    private var commentPhotos: [String: [UIImage]] = [:] // commentId -> photos
    private var reviewCommentCounts: [String: Int] = [:] // reviewId -> comment count

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
        
        let photoState = photoLoadingStates[placeId] ?? .idle
        let reviewState = reviewLoadingStates[placeId] ?? .idle

        // Consider loaded if both photos and reviews are either loaded or in error state
        // (we don't want to wait forever if there's an error)
        let photosReady: Bool
        switch photoState {
        case .loaded, .error:
            photosReady = true
        case .idle, .loading:
            photosReady = false
        }

        let reviewsReady: Bool
        switch reviewState {
        case .loaded, .error:
            reviewsReady = true
        case .idle, .loading:
            reviewsReady = false
        }

        // Note: reviewPhotosForAbout is loaded separately and asynchronously, but we don't want to block
        // the main place detail view from loading. The about section can show a loading state independently.

        let wasLoaded = isCurrentPlaceFullyLoaded
        isCurrentPlaceFullyLoaded = photosReady && reviewsReady
        
        // Debug logging when the state changes
        if !wasLoaded && isCurrentPlaceFullyLoaded {
            print("✅ [SelectedPlaceViewModel] Place '\(selectedPlace?.name ?? "Unknown")' is now fully loaded")
        }
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
            print("📊 [SelectedPlaceViewModel] Place '\(place.name)' already has ratings (\(rating)), skipping refresh")
            return
        }
        
        // Backend now accepts UUID and handles everything automatically
        let placeId = place.id.uuidString
        
        print("📊 [SelectedPlaceViewModel] Fetching external ratings for '\(place.name)' using UUID: \(placeId)")
        
        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let updatedPlace):
                DispatchQueue.main.async {
                    // Only update if this is still the selected place
                    guard self.selectedPlace?.id == place.id else {
                        print("📊 [SelectedPlaceViewModel] Place changed, skipping rating update")
                        return
                    }
                    
                    // Update the selected place with fresh ratings
                    var updatedSelectedPlace = self.selectedPlace
                    updatedSelectedPlace?.rating = updatedPlace.rating
                    updatedSelectedPlace?.userRatingsTotal = updatedPlace.userRatingsTotal
                    
                    print("✅ [SelectedPlaceViewModel] Updated ratings for '\(place.name)': \(updatedPlace.rating ?? 0) (\(updatedPlace.userRatingsTotal ?? 0) reviews)")
                    
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
            } else {
                print("✅ [SelectedPlaceViewModel] Successfully updated place '\(place.name)' in Firestore")
            }
        }
    }
    
    /// Select a place and fetch fresh details from backend
    /// Use this when a user clicks on a place from lists, maps, etc.
    func selectPlaceAndFetchDetails(_ place: DetailPlace) {
        print("🎯 [SelectedPlaceViewModel] Selecting place: '\(place.name)' with ID: \(place.id)")
        
        // Backend now accepts UUID and handles everything automatically
        // Just send the UUID as place_id and "google" as provider
        let placeId = place.id.uuidString
        
        print("🌐 [SelectedPlaceViewModel] Fetching fresh details for '\(place.name)' using UUID: \(placeId)")
        
        // Fetch fresh details from backend first
        mesaBackendService.fetchPlaceDetails(placeId: placeId, source: "google") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let freshPlace):
                DispatchQueue.main.async {
                    // Preserve the original ID and merge fresh data
                    var updatedPlace = freshPlace
                    updatedPlace.id = place.id
                    
                    print("✅ [SelectedPlaceViewModel] Fetched fresh details for '\(place.name)'")
                    print("   - Rating: \(updatedPlace.rating ?? 0) (\(updatedPlace.userRatingsTotal ?? 0) reviews)")
                    
                    // Update selected place with fresh data
                    // This will trigger didSet which handles loading reviews/photos
                    self.selectedPlace = updatedPlace
                    
                    // Update Firestore in background
                    self.updatePlaceInFirestore(updatedPlace)
                }
                
            case .failure(let error):
                print("❌ [SelectedPlaceViewModel] Failed to fetch fresh details for '\(place.name)': \(error.localizedDescription)")
                // Set cached data - didSet will handle loading reviews/photos
                DispatchQueue.main.async {
                    self.selectedPlace = place
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
        
        // Fetch reviews for the specific place
        Task {
            do {
                let reviews = try await reviewService.fetchPlaceReviews(placeId: placeId, latestOnly: false)
                
                await MainActor.run {
                    self.placeReviews[placeId] = reviews
                    
                    reviews.forEach { review in
                        self.loadReviewPhotos(for: review)
                        self.loadProfilePhoto(for: review)
                        self.loadCommentCountForReview(placeId: placeId, reviewId: review.id)
                    }
                    self.reviewLoadingStates[placeId] = .loaded
                    self.updateCurrentPlaceFullyLoaded()
                    print("✅ [SelectedPlaceViewModel] Loaded \(reviews.count) reviews for place \(placeId)")
                }
            } catch {
                await MainActor.run {
                    print("❌ [SelectedPlaceViewModel] Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                    self.reviewLoadingStates[placeId] = .error(error)
                    self.placeReviews[placeId] = []
                    self.updateCurrentPlaceFullyLoaded()
                }
            }
        }
    }
    
    
    // MARK: - Photo Loading
    
    private func resetPhotoLoading() {
        if let placeId = selectedPlace?.id.uuidString {
            placePhotos[placeId]?.removeAll()
            photoLoadingStates[placeId] = .idle
            reviewPhotosForAbout[placeId]?.removeAll()
            reviewPhotosForAboutLoadingStates[placeId] = .idle
            lastPhotoDocument = nil
            allPhotosLoaded = false
        }
    }
    
    func loadMorePhotos() {
        guard let place = selectedPlace, !allPhotosLoaded else {
            return
        }
        
        getPlacePhotos(for: place, loadMore: true)
    }

    private func getPlacePhotos(for place: DetailPlace, loadMore: Bool = false) {
        let placeId = place.id.uuidString
        
        print("📸 [getPlacePhotos] Called for place: \(place.name) (ID: \(placeId))")
        print("   - loadMore: \(loadMore)")
        print("   - Current state: \(photoLoadingStates[placeId] ?? .idle)")
        
        // Don't fetch if already loading
        if photoLoadingStates[placeId] == .loading && !loadMore {
            print("⚠️ [getPlacePhotos] Already loading, skipping")
            return
        }
        
        DispatchQueue.main.async {
            print("📸 [getPlacePhotos] Setting state to .loading")
            self.photoLoadingStates[placeId] = .loading
        }
        
        print("📸 [getPlacePhotos] Fetching reviews for place...")
        // Fetch reviews for the specific place to get photos
        Task {
            do {
                let reviews = try await reviewService.fetchPlaceReviews(placeId: placeId, latestOnly: false)
                
                print("📸 [getPlacePhotos] Fetched \(reviews.count) reviews for place \(placeId)")
                
                var photoURLs: [String] = []
                for review in reviews {
                    photoURLs.append(contentsOf: review.images)
                }
                
                print("📸 [getPlacePhotos] Extracted \(photoURLs.count) photo URLs from reviews")
                
                // If no photos found in any reviews, mark as loaded
                if photoURLs.isEmpty {
                    print("📸 [getPlacePhotos] No photos found, marking as loaded with empty array")
                    await MainActor.run {
                        self.photoLoadingStates[placeId] = .loaded
                        self.placePhotos[placeId] = []
                        self.allPhotosLoaded = true
                        self.updateCurrentPlaceFullyLoaded()
                    }
                    return
                }
                
                // Paginate the photo URLs
                let startIndex = self.placePhotos[placeId]?.count ?? 0
                let endIndex = min(startIndex + self.photoPageLimit, photoURLs.count)
                
                print("📸 [getPlacePhotos] Pagination: startIndex=\(startIndex), endIndex=\(endIndex), total=\(photoURLs.count)")
                
                guard startIndex < endIndex else {
                    // No more photos to load
                    print("📸 [getPlacePhotos] No more photos to load, marking as complete")
                    await MainActor.run {
                        self.allPhotosLoaded = true
                        self.photoLoadingStates[placeId] = .loaded
                        self.updateCurrentPlaceFullyLoaded()
                    }
                    return
                }
                
                let urlsToFetch = Array(photoURLs[startIndex..<endIndex])
                print("📸 [getPlacePhotos] Fetching \(urlsToFetch.count) images from URLs...")
                
                // Load images in parallel using TaskGroup
                var loadedImages: [UIImage] = []
                
                await withTaskGroup(of: UIImage?.self) { group in
                    for imageUrl in urlsToFetch {
                        group.addTask {
                            await self.loadImageFromURL(imageUrl: imageUrl)
                        }
                    }
                    
                    for await image in group {
                        if let image = image {
                            loadedImages.append(image)
                        }
                    }
                }
                
                await MainActor.run {
                    var currentPhotos = self.placePhotos[placeId] ?? []
                    currentPhotos.append(contentsOf: loadedImages)
                    self.placePhotos[placeId] = currentPhotos
                    self.photoLoadingStates[placeId] = .loaded
                    
                    print("✅ [getPlacePhotos] Successfully loaded \(loadedImages.count) photos. Total now: \(currentPhotos.count)")
                    
                    // Check if all photos have been loaded
                    if currentPhotos.count >= photoURLs.count {
                        self.allPhotosLoaded = true
                    }
                    self.updateCurrentPlaceFullyLoaded()
                }
            } catch {
                await MainActor.run {
                    print("❌ [getPlacePhotos] Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                    self.photoLoadingStates[placeId] = .error(error)
                    self.updateCurrentPlaceFullyLoaded()
                }
            }
        }
    }

    func loadReviewPhotosForAbout(for place: DetailPlace) {
        let placeId = place.id.uuidString

        // Don't fetch if already loading
        if reviewPhotosForAboutLoadingStates[placeId] == .loading {
            return
        }

        DispatchQueue.main.async {
            self.reviewPhotosForAboutLoadingStates[placeId] = .loading
        }

        // Get review photo URLs from Firestore
        mesaBackendService.getReviewPhotos(for: placeId) { [weak self] photoUrls in
            guard let self = self else { return }

            if photoUrls.isEmpty {
                // No review photos found
                DispatchQueue.main.async {
                    self.reviewPhotosForAbout[placeId] = []
                    self.reviewPhotosForAboutLoadingStates[placeId] = .loaded
                    self.updateCurrentPlaceFullyLoaded()
                }
                return
            }

            // Fetch the actual images from storage
            self.imageService.fetchPhotosFromStorage(urls: photoUrls) { [weak self] images, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    if let error = error {
                        print("Error fetching review photos for about section: \(error.localizedDescription)")
                        self.reviewPhotosForAboutLoadingStates[placeId] = .error(error)
                        self.reviewPhotosForAbout[placeId] = []
                    } else {
                        self.reviewPhotosForAbout[placeId] = images ?? []
                        self.reviewPhotosForAboutLoadingStates[placeId] = .loaded
                    }
                    self.updateCurrentPlaceFullyLoaded()
                }
            }
        }
    }

    private func loadReviewPhotos<T: ReviewProtocol>(for review: T) {
        let reviewId = review.id
        guard !review.images.isEmpty else {
            DispatchQueue.main.async {
                self.reviewPhotos[reviewId] = []
                self.reviewPhotoLoadingStates[reviewId] = .loaded
            }
            return
        }
        
        DispatchQueue.main.async {
            self.reviewPhotoLoadingStates[reviewId] = .loading
        }
        
        // Load only the first 4 images initially for better performance
        let initialImageCount = min(4, review.images.count)
        let initialImageUrls = Array(review.images.prefix(initialImageCount))
        
        // Load initial images in parallel using TaskGroup
        Task {
            var loadedImages: [UIImage] = []
            
            await withTaskGroup(of: UIImage?.self) { group in
                for imageUrl in initialImageUrls {
                    group.addTask {
                        await self.loadImageFromURL(imageUrl: imageUrl)
                    }
                }
                
                for await image in group {
                    if let image = image {
                        loadedImages.append(image)
                    }
                }
            }
            
            await MainActor.run {
                self.reviewPhotos[reviewId] = loadedImages
                self.reviewPhotoLoadingStates[reviewId] = .loaded
                print("✅ [SelectedPlaceViewModel] Loaded \(loadedImages.count) initial images for review \(reviewId) (total available: \(review.images.count))")
            }
        }
    }
    
    /// Load more photos for a specific review when user scrolls
    func loadMoreReviewPhotos(for reviewId: String, allImageUrls: [String]) {
        guard let currentPhotos = reviewPhotos[reviewId],
              currentPhotos.count < allImageUrls.count else {
            return // Already loaded all photos or no photos to load
        }
        
        let startIndex = currentPhotos.count
        let endIndex = min(startIndex + 4, allImageUrls.count) // Load 4 more at a time
        let urlsToLoad = Array(allImageUrls[startIndex..<endIndex])
        
        print("📸 [SelectedPlaceViewModel] Loading more photos for review \(reviewId): \(startIndex) to \(endIndex-1)")
        
        Task {
            var newImages: [UIImage] = []
            
            await withTaskGroup(of: UIImage?.self) { group in
                for imageUrl in urlsToLoad {
                    group.addTask {
                        await self.loadImageFromURL(imageUrl: imageUrl)
                    }
                }
                
                for await image in group {
                    if let image = image {
                        newImages.append(image)
                    }
                }
            }
            
            await MainActor.run {
                self.reviewPhotos[reviewId]?.append(contentsOf: newImages)
                print("✅ [SelectedPlaceViewModel] Loaded \(newImages.count) more images for review \(reviewId) (total: \(self.reviewPhotos[reviewId]?.count ?? 0))")
            }
        }
    }
    
    /// Load more photos for the about section when user scrolls
    func loadMorePhotosForAbout(placeId: String) {
        // This method should load more photos from all reviews for the about section
        // For now, we'll use the existing loadMorePhotos method which handles place-level photo pagination
        loadMorePhotos()
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
    
    /// Load image directly from URL
    private func loadImageFromURL(imageUrl: String) async -> UIImage? {
        guard let url = URL(string: imageUrl) else {
            print("⚠️ [SelectedPlaceViewModel] Invalid image URL: \(imageUrl)")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("⚠️ [SelectedPlaceViewModel] Failed to load image from URL: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Public method to reload review photos
    func reloadReviewPhotos<T: ReviewProtocol>(for review: T) {
        self.loadReviewPhotos(for: review)
    }
    
    private func loadProfilePhoto<T: ReviewProtocol>(for review: T) {
        let userId = review.userId
        let photoUrlString = review.profilePhotoUrl
        
        guard !photoUrlString.isEmpty else {
            DispatchQueue.main.async {
                self.profilePhotoLoadingStates[userId] = .loaded
                self.userProfilePhotos[userId] = nil
            }
            return
        }
        
        if userProfilePhotos[userId] != nil {
            return
        }
        
        DispatchQueue.main.async {
            self.profilePhotoLoadingStates[userId] = .loading
        }
        
        guard let url = URL(string: photoUrlString) else {
            DispatchQueue.main.async {
                self.profilePhotoLoadingStates[userId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid profile photo URL"]))
                self.userProfilePhotos[userId] = nil
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching profile photo for user \(userId): \(error.localizedDescription)")
                    self.profilePhotoLoadingStates[userId] = .error(error)
                    self.userProfilePhotos[userId] = nil
                } else if let data = data, let image = UIImage(data: data) {
                    self.userProfilePhotos[userId] = image
                    self.profilePhotoLoadingStates[userId] = .loaded
                } else {
                    self.profilePhotoLoadingStates[userId] = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode profile photo"]))
                    self.userProfilePhotos[userId] = nil
                }
            }
        }.resume()
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
    
    // MARK: - Comment Methods
    
    func loadCommentsForReview(reviewId: String) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        DispatchQueue.main.async {
            self.commentLoadingStates[reviewId] = .loading
        }
        
        // Add limit and order by timestamp to get only the most recent 5 comments
        reviewService.fetchComments(for: reviewId) { [weak self] comments, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading comments: \(error.localizedDescription)")
                    self.commentLoadingStates[reviewId] = .error(error)
                } else {
                    let fetchedComments = comments ?? []
                    self.placeReviewComments[reviewId] = fetchedComments
                    
                    // Update our count - but don't reset if we already have a larger count
                    // This ensures we display the correct total even when loading limited comments
                    if self.reviewCommentCounts[reviewId] == nil || self.reviewCommentCounts[reviewId]! < fetchedComments.count {
                        self.reviewCommentCounts[reviewId] = fetchedComments.count
                    }
                    
                    self.commentLoadingStates[reviewId] = .loaded
                    
                    // Efficiently load photos only for comments that have them
                    for comment in fetchedComments where !comment.images.isEmpty {
                        self.loadCommentPhotos(for: comment)
                    }
                }
            }
        }
    }
    
    func addComment(reviewId: String, text: String, images: [UIImage], userId: String, userFirstName: String, userLastName: String, profilePhotoUrl: String) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        let commentId = UUID().uuidString
        
        var comment = Comment(
            id: commentId,
            reviewId: reviewId,
            userId: userId,
            profilePhotoUrl: profilePhotoUrl,
            userFirstName: userFirstName,
            userLastName: userLastName,
            commentText: text,
            timestamp: Date(),
            images: [],
            likes: 0
        )
        
        ImageService.shared.uploadImagesForComment(comment: comment, images: images) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let downloadURLs):
                comment.images = downloadURLs
                
                ReviewService.shared.addComment(reviewId: reviewId, userId: userId, text: comment.commentText) { [weak self] result in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            // Add the comment to our local collection
                            var currentComments = self.placeReviewComments[reviewId] ?? []
                            currentComments.insert(comment, at: 0) // Add at the top
                            self.placeReviewComments[reviewId] = currentComments
                            
                            // Update the comment count
                            let currentCount = self.reviewCommentCounts[reviewId] ?? 0
                            self.reviewCommentCounts[reviewId] = currentCount + 1
                            
                            // Ensure loading state is set to loaded
                            self.commentLoadingStates[reviewId] = .loaded
                            
                            // Load comment photos if any
                            if !comment.images.isEmpty {
                                self.loadCommentPhotos(for: comment)
                            }
                            
                        case .failure(let error):
                            print("Error adding comment: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure(let error):
                print("Error uploading comment images: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadCommentPhotos(for comment: Comment) {
        // Skip if already loaded or no images
        if commentPhotos[comment.id] != nil || comment.images.isEmpty {
            return
        }
        
        imageService.fetchPhotosFromStorage(urls: comment.images) { [weak self] images, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading comment photos: \(error.localizedDescription)")
                } else if let images = images {
                    self.commentPhotos[comment.id] = images
                }
            }
        }
    }
    
    // MARK: - Comment Public Accessors
    
    func comments(for reviewId: String) -> [Comment] {
        return placeReviewComments[reviewId] ?? []
    }
    
    func commentLoadingState(for reviewId: String) -> LoadingState {
        return commentLoadingStates[reviewId] ?? .idle
    }
    
    func commentPhotos(for comment: Comment) -> [UIImage] {
        return commentPhotos[comment.id] ?? []
    }
    
    // Returns the number of comments for a specific review
    func commentCount(for reviewId: String) -> Int {
        // First check our stored counts
        if let count = reviewCommentCounts[reviewId] {
            return count
        }
        // Fall back to the comment array count if needed
        return placeReviewComments[reviewId]?.count ?? 0
    }

    // MARK: - Public Methods
    func addReview<T: ReviewProtocol>(_ review: T) {
        guard let placeId = selectedPlace?.id.uuidString else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var currentReviews = self.placeReviews[placeId] ?? []
            currentReviews.insert(review, at: 0) // Insert at the beginning instead of appending
            self.placeReviews[placeId] = currentReviews
            self.loadReviewPhotos(for: review)
            self.loadProfilePhoto(for: review)
        }
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

                            // Clean up cached photos for this review
                            self.reviewPhotos.removeValue(forKey: reviewId)
                            self.reviewPhotoLoadingStates.removeValue(forKey: reviewId)
                            
                            // Clean up cached comments for this review
                            self.placeReviewComments.removeValue(forKey: reviewId)
                            self.commentLoadingStates.removeValue(forKey: reviewId)
                            self.reviewCommentCounts.removeValue(forKey: reviewId)
                            
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
    
    // MARK: - Public Accessors
    var reviews: [any ReviewProtocol] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeReviews[placeId] ?? []
    }
    
    var photoLoadingState: LoadingState {
        guard let placeId = selectedPlace?.id.uuidString else { return .idle }
        return photoLoadingStates[placeId] ?? .idle
    }
    
    var photos: [UIImage] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placePhotos[placeId] ?? []
    }
    
    func photos(for review: any ReviewProtocol) -> [UIImage] {
        return reviewPhotos[review.id] ?? []
    }
    
    func photoLoadingState(for review: any ReviewProtocol) -> LoadingState {
        return reviewPhotoLoadingStates[review.id] ?? .idle
    }
    
    func profilePhoto(forUserId userId: String) -> UIImage? {
        return userProfilePhotos[userId]
    }
    
    func profilePhotoLoadingState(forUserId userId: String) -> LoadingState {
        return profilePhotoLoadingStates[userId] ?? .idle
    }
    
    func reviewLoadingState(forPlaceId placeId: String) -> LoadingState {
        return reviewLoadingStates[placeId] ?? .idle
    }

    func reviewPhotosForAbout(forPlaceId placeId: String) -> [UIImage] {
        return reviewPhotosForAbout[placeId] ?? []
    }

    func reviewPhotosForAboutLoadingState(forPlaceId placeId: String) -> LoadingState {
        return reviewPhotosForAboutLoadingStates[placeId] ?? .idle
    }

    var allPhotosLoadedForCurrentPlace: Bool {
        return allPhotosLoaded
    }
    
    func likeReview<T: ReviewProtocol>(_ review: T, userId: String) {
        print("⚠️ [SelectedPlaceViewModel] likeReview not fully implemented")
        // TODO: Implement proper like/unlike logic with Supabase
    }

    // Add helper method to check if a review is liked
    func isReviewLiked(_ reviewId: String) -> Bool {
        return likedReviews.contains(reviewId)
    }
    
    // Load comment count for a review (without loading all comments)
    func loadCommentCountForReview(placeId: String, reviewId: String) {
        print("⚠️ [SelectedPlaceViewModel] loadCommentCountForReview not fully implemented")
        // TODO: Implement with Supabase
    }

    // Load additional comments beyond the initial 5
    func loadMoreComments(placeId: String, reviewId: String, limit: Int) {
        DispatchQueue.main.async {
            // Don't change loading state to .loading to avoid flickering the UI
            // Just keep the existing comments visible while loading more
        }
        
        reviewService.fetchComments(for: reviewId) { [weak self] comments, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading more comments: \(error.localizedDescription)")
                    // Don't update loading state to error to preserve existing comments
                } else if let fetchedComments = comments {
                    self.placeReviewComments[reviewId] = fetchedComments
                    
                    // Only update comment count if we get more than we knew about
                    if self.reviewCommentCounts[reviewId] == nil || self.reviewCommentCounts[reviewId]! < fetchedComments.count {
                        self.reviewCommentCounts[reviewId] = fetchedComments.count
                    }
                    
                    // Load photos for new comments
                    for comment in fetchedComments where !comment.images.isEmpty && self.commentPhotos[comment.id] == nil {
                        self.loadCommentPhotos(for: comment)
                    }
                }
            }
        }
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
        
        // Save to main places collection
        placeService.addToAllPlaces(place: newPlace) { error in
            if let error = error {
                print("Error saving place to main collection: \(error.localizedDescription)")
            } else {
                print("Successfully saved place to main collection")
                
                // Save to user's myPlaces collection
                self.placeService.addToMyPlaces(userId: userId, place: newPlace) { error in
                    if let error = error {
                        print("Error saving place to user's collection: \(error.localizedDescription)")
                    } else {
                        print("Successfully saved place to user's myPlaces collection")
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
}