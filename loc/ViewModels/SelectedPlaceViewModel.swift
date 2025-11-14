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
    
    func setDetailPlaceViewModel(_ viewModel: DetailPlaceViewModel) {
        self.detailPlaceViewModel = viewModel
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
        guard let place = selectedPlace else {
            print("⚠️ [SelectedPlaceViewModel] selectedPlace is nil, skipping setup")
            return
        }

        guard let currentLocation = locationManager.currentLocation else {
            print("⚠️ [SelectedPlaceViewModel] currentLocation is nil, skipping setup")
            return
        }

        print("📍 [SelectedPlaceViewModel] Place and location available")
        print("   - Rating: \(place.rating ?? 0)")
        print("   - Categories: \(place.categories?.count ?? 0)")
        print("   - UserRatingsTotal: \(place.userRatingsTotal ?? 0)")

        if placeNeedsCompleteDetails(place) {
            handlePlaceWithIncompleteDetails(place, currentLocation: currentLocation.coordinate)
        } else {
            print("✅ [SelectedPlaceViewModel] Place has complete details, continuing with setup")
            continueWithPlaceSetup(place: place, currentLocation: currentLocation.coordinate)
        }
    }

    private func handlePlaceWithIncompleteDetails(_ place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        print("⚠️ [SelectedPlaceViewModel] Place missing details, fetching complete details...")

        if isFetchingFreshDetails {
            print("ℹ️ [SelectedPlaceViewModel] Fresh details fetch in progress, using current data for now")
            continueWithPlaceSetup(place: place, currentLocation: currentLocation)
            return
        }

        fetchCompletePlaceDetails(for: place) { [weak self] updatedPlace in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let updatedPlace = updatedPlace {
                    print("✅ [SelectedPlaceViewModel] Got complete details, updating place")
                    self.isUpdatingPlaceDetails = true
                    self.selectedPlace = updatedPlace
                    self.isUpdatingPlaceDetails = false

                    print("🎬 [SelectedPlaceViewModel] Manually calling continueWithPlaceSetup after bypass")
                    self.continueWithPlaceSetup(place: updatedPlace, currentLocation: currentLocation)
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
        
        // Reset photo loading state for new place
        resetPhotoLoading()
        
        // Load reviews first, then photos will be loaded after reviews complete
        loadReviews(for: place)
        loadExternalReviewPhotos(for: place, reset: true)

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
    @Published var isDetailSheetPresented: Bool = false
    @Published var isRestaurantOpen: Bool = false // New property to track open status
    @Published var allowAutoPresent: Bool = true
    @Published var shouldAnimateMapToPlace: Bool = false // Track if map should animate to place location
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache for place-level photos by placeId
    @Published private var placeReviews: [String: [any ReviewProtocol]] = [:] // Cache for reviews by placeId
    @Published private var placeTikToks: [String: [TikTokVideo]] = [:] // Cache for TikToks by placeId
    @Published private var reviewPhotos: [String: [UIImage]] = [:] // Cache for review photos by reviewId
    @Published private var userProfilePhotos: [String: UIImage] = [:] // Cache for profile photos by userId
    @Published private var restaurantTypes: [String: String] = [:] // Dictionary to store restaurant types by placeId
    @Published private var reviewPhotosForAbout: [String: [UIImage]] = [:] // Cache for review photos in about section by placeId
    @Published private var externalReviewPhotosByPlace: [String: [UIImage]] = [:] // Cache for external review photos by placeId
    @Published private var externalReviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for external review photos
    @Published private var externalReviewPhotosAllLoadedByPlace: [String: Bool] = [:] // Track completion of external photo loading per place
    
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
    
    private var externalReviewImageURLCache: [String: [String]] = [:] // placeId -> photo URLs
    private var externalReviewReviewOffsets: [String: Int] = [:] // placeId -> offset into external reviews
    private var externalReviewPhotoCursor: [String: Int] = [:] // placeId -> number of image URLs consumed
    private var externalReviewReviewHasMore: [String: Bool] = [:] // placeId -> more review pages available
    private var externalReviewRetryAttempts: [String: Int] = [:] // placeId -> retry attempt count
    private let externalReviewReviewBatchSize = 10
    private let externalReviewPhotoBatchSize = 5
    private let maxExternalReviewRetries = 3 // Maximum retry attempts for external reviews
    private let externalReviewRetryDelay: TimeInterval = 2.0 // Delay between retries in seconds
    
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
                        print("ℹ️ [SelectedPlaceViewModel] Selected place changed before fresh details returned, skipping update")
                        return
                    }

                    self.isFetchingFreshDetails = false

                    // Preserve the original ID and merge fresh data
                    var updatedPlace = freshPlace
                    updatedPlace.id = place.id
                    
                    self.selectedPlace = updatedPlace
                    
                    // Update Firestore in background
                    self.updatePlaceInFirestore(updatedPlace)
                }
                
            case .failure(let error):
                print("❌ [SelectedPlaceViewModel] Failed to fetch fresh details for '\(place.name)': \(error.localizedDescription)")
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
                    
                    reviews.forEach { review in
                        self.loadReviewPhotos(for: review)
                        self.loadProfilePhotoFromURL(userId: review.userId, photoUrl: review.profilePhotoUrl)
                        self.loadCommentCountForReview(placeId: placeId, reviewId: review.id)
                    }
                    self.reviewLoadingStates[placeId] = .loaded
                    
                    // Now that reviews are loaded, load photos from them
                    if let place = self.selectedPlace, place.id.uuidString == placeId {
                        print("📸 [SelectedPlaceViewModel] Reviews loaded, now loading photos")
                        self.getPlacePhotos(for: place)
                        self.loadReviewPhotosForAbout(for: place)
                    }
                    
                    self.updateCurrentPlaceFullyLoaded()
                }
            } catch {
                await MainActor.run {
                    print("❌ [SelectedPlaceViewModel] Error fetching reviews/TikToks for place \(placeId): \(error.localizedDescription)")
                    self.reviewLoadingStates[placeId] = .error(error)
                    self.placeReviews[placeId] = []
                    self.placeTikToks[placeId] = []
                    
                    // Even if reviews fail, try to load photos (will result in empty)
                    if let place = self.selectedPlace, place.id.uuidString == placeId {
                        self.getPlacePhotos(for: place)
                        self.loadReviewPhotosForAbout(for: place)
                    }
                    
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
            externalReviewPhotosByPlace[placeId]?.removeAll()
            externalReviewPhotoLoadingStates[placeId] = .idle
            externalReviewPhotosAllLoadedByPlace[placeId] = false
            externalReviewImageURLCache[placeId]?.removeAll()
            externalReviewReviewOffsets[placeId] = 0
            externalReviewPhotoCursor[placeId] = 0
            externalReviewReviewHasMore[placeId] = true
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
        
        // Don't fetch if already loading
        if photoLoadingStates[placeId] == .loading && !loadMore {
            return
        }
        
        DispatchQueue.main.async {
            self.photoLoadingStates[placeId] = .loading
        }
        
        // Use cached reviews to get photos (reviews are already loaded at this point)
        Task {
            let reviews = await MainActor.run { self.placeReviews[placeId] ?? [] }
            
            var photoURLs: [String] = []
            for review in reviews {
                photoURLs.append(contentsOf: review.images)
            }
            
            // If no photos found in any reviews, mark as loaded
            if photoURLs.isEmpty {
                await MainActor.run {
                    self.photoLoadingStates[placeId] = .loaded
                    self.placePhotos[placeId] = []
                    self.allPhotosLoaded = true
                    self.updateCurrentPlaceFullyLoaded()
                }
                return
            }
            
            // Paginate the photo URLs
            let startIndex = await MainActor.run { self.placePhotos[placeId]?.count ?? 0 }
            let endIndex = min(startIndex + self.photoPageLimit, photoURLs.count)
            
            guard startIndex < endIndex else {
                // No more photos to load
                await MainActor.run {
                    self.allPhotosLoaded = true
                    self.photoLoadingStates[placeId] = .loaded
                    self.updateCurrentPlaceFullyLoaded()
                }
                return
            }
            
            let urlsToFetch = Array(photoURLs[startIndex..<endIndex])
            
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
                
                // Check if all photos have been loaded
                if currentPhotos.count >= photoURLs.count {
                    self.allPhotosLoaded = true
                }
                self.updateCurrentPlaceFullyLoaded()
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

        // Use cached reviews to get photo URLs (reviews are already loaded at this point)
        Task {
            let reviews = await MainActor.run { self.placeReviews[placeId] ?? [] }
            
            // Extract photo URLs from reviews
            var photoURLs: [String] = []
            for review in reviews {
                photoURLs.append(contentsOf: review.images)
            }
            
            // If no photos found, mark as loaded with empty array
            if photoURLs.isEmpty {
                await MainActor.run {
                    self.reviewPhotosForAbout[placeId] = []
                    self.reviewPhotosForAboutLoadingStates[placeId] = .loaded
                    self.updateCurrentPlaceFullyLoaded()
                }
                return
            }
            
            // Load the first few images for the about section (limit to avoid loading too many)
            let urlsToLoad = Array(photoURLs.prefix(6))
            var loadedImages: [UIImage] = []
            
            await withTaskGroup(of: UIImage?.self) { group in
                for imageUrl in urlsToLoad {
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
                self.reviewPhotosForAbout[placeId] = loadedImages
                self.reviewPhotosForAboutLoadingStates[placeId] = .loaded
                self.updateCurrentPlaceFullyLoaded()
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
        
        // Loading more photos for review
        
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
            }
        }
    }
    
    private struct ExternalReviewPaginationState {
        let placeId: String
        var cachedURLs: [String]
        var reviewOffset: Int
        var hasMoreReviews: Bool
        var photoCursor: Int
    }
    
    private func extendExternalReviewURLs(placeId: String, state: inout ExternalReviewPaginationState) async throws {
        while state.cachedURLs.count < state.photoCursor + externalReviewPhotoBatchSize && state.hasMoreReviews {
            let page = try await reviewService.fetchExternalReviewMedia(
                placeId: placeId,
                reviewOffset: state.reviewOffset,
                reviewLimit: externalReviewReviewBatchSize
            )
            
            state.cachedURLs.append(contentsOf: page.urls)
            state.reviewOffset = page.nextReviewOffset
            state.hasMoreReviews = page.hasMore
        }
    }
    
    private func loadExternalReviewImages(from urls: [String]) async -> [UIImage] {
        guard !urls.isEmpty else { return [] }
        
        var loadedImages: [UIImage] = []
        
        await withTaskGroup(of: UIImage?.self) { group in
            for url in urls {
                group.addTask {
                    await self.loadImageFromURL(imageUrl: url)
                }
            }
            
            for await image in group {
                if let image {
                    loadedImages.append(image)
                }
            }
        }
        
        return loadedImages
    }
    
    private func loadExternalReviewPhotos(for place: DetailPlace, reset: Bool) {
        let placeId = place.id.uuidString
        
        if externalReviewPhotoLoadingStates[placeId] == .loading {
            return
        }
        
        Task {
            await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: reset)
        }
    }
    
    /// Internal method that handles loading external reviews with retry logic
    private func loadExternalReviewPhotosInternal(for place: DetailPlace, placeId: String, reset: Bool) async {
            await MainActor.run {
                self.externalReviewPhotoLoadingStates[placeId] = .loading
            if reset {
                self.externalReviewRetryAttempts[placeId] = 0
            }
            }
            
            var state = await externalReviewPaginationState(for: placeId, reset: reset)
            
            do {
                try await extendExternalReviewURLs(placeId: placeId, state: &state)
            } catch {
                await MainActor.run {
                    self.externalReviewPhotoLoadingStates[placeId] = .error(error)
                }
                return
            }
            
            let urlsToLoad = Array(state.cachedURLs.dropFirst(state.photoCursor).prefix(externalReviewPhotoBatchSize))
            
        // If no reviews found and we're still within retry limit, retry
        if urlsToLoad.isEmpty && state.cachedURLs.isEmpty && !state.hasMoreReviews {
            let retryCount = await MainActor.run {
                return self.externalReviewRetryAttempts[placeId] ?? 0
            }
            
            if retryCount < maxExternalReviewRetries {
                await MainActor.run {
                    self.externalReviewRetryAttempts[placeId] = retryCount + 1
                    print("🔄 [SelectedPlaceViewModel] No external reviews for \(placeId), retrying (\(retryCount + 1)/\(maxExternalReviewRetries))...")
                }
                
                try? await Task.sleep(nanoseconds: UInt64(externalReviewRetryDelay * 1_000_000_000))
                await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: false)
                return
            } else {
                print("⚠️ [SelectedPlaceViewModel] No external reviews after \(maxExternalReviewRetries) retries for \(placeId)")
            }
            }
            
        // Load images if we have URLs, otherwise mark as loaded (empty state)
        if urlsToLoad.isEmpty {
            await updateExternalReviewPaginationState(state, newImages: [], loadingState: .loaded)
        } else {
            let loadedImages = await loadExternalReviewImages(from: urlsToLoad)
            state.photoCursor += urlsToLoad.count
            
            await MainActor.run {
                // Reset retry count on success
                self.externalReviewRetryAttempts[placeId] = 0
            }
            
            await updateExternalReviewPaginationState(state, newImages: loadedImages, loadingState: .loaded)
        }
    }
    
    @MainActor
    private func externalReviewPaginationState(for placeId: String, reset: Bool) -> ExternalReviewPaginationState {
        if reset {
            externalReviewPhotosByPlace[placeId] = []
            externalReviewImageURLCache[placeId] = []
            externalReviewReviewOffsets[placeId] = 0
            externalReviewPhotoCursor[placeId] = 0
            externalReviewReviewHasMore[placeId] = true
            externalReviewPhotosAllLoadedByPlace[placeId] = false
        }
        
        let cachedURLs = externalReviewImageURLCache[placeId] ?? []
        let reviewOffset = externalReviewReviewOffsets[placeId] ?? 0
        let hasMore = externalReviewReviewHasMore[placeId] ?? true
        let cursor = externalReviewPhotoCursor[placeId] ?? 0
        
        return ExternalReviewPaginationState(
            placeId: placeId,
            cachedURLs: cachedURLs,
            reviewOffset: reviewOffset,
            hasMoreReviews: hasMore,
            photoCursor: cursor
        )
    }
    
    @MainActor
    private func updateExternalReviewPaginationState(_ state: ExternalReviewPaginationState, newImages: [UIImage], loadingState: LoadingState) {
        if !newImages.isEmpty {
            var currentPhotos = externalReviewPhotosByPlace[state.placeId] ?? []
            currentPhotos.append(contentsOf: newImages)
            externalReviewPhotosByPlace[state.placeId] = currentPhotos
        } else if externalReviewPhotosByPlace[state.placeId] == nil {
            externalReviewPhotosByPlace[state.placeId] = []
        }
        
        externalReviewImageURLCache[state.placeId] = state.cachedURLs
        externalReviewReviewOffsets[state.placeId] = state.reviewOffset
        externalReviewReviewHasMore[state.placeId] = state.hasMoreReviews
        externalReviewPhotoCursor[state.placeId] = state.photoCursor
        
        let noMorePhotos = !state.hasMoreReviews && state.photoCursor >= state.cachedURLs.count
        externalReviewPhotosAllLoadedByPlace[state.placeId] = noMorePhotos
        externalReviewPhotoLoadingStates[state.placeId] = loadingState
    }
    
    /// Load more photos for the about section when user scrolls
    func loadMorePhotosForAbout(placeId: String) {
        // This method should load more photos from all reviews for the about section
        // For now, we'll use the existing loadMorePhotos method which handles place-level photo pagination
        loadMorePhotos()
    }

    func loadInitialExternalReviewPhotos() {
        guard let place = selectedPlace else { return }
        let placeId = place.id.uuidString
        
        if externalReviewPhotosByPlace[placeId] != nil || externalReviewPhotoLoadingStates[placeId] == .loading {
            return
        }
        
        loadExternalReviewPhotos(for: place, reset: false)
    }

    func loadMoreExternalReviewPhotosIfNeeded(currentIndex: Int) {
        guard let place = selectedPlace else { return }
        let placeId = place.id.uuidString
        
        guard !externalReviewPhotosFullyLoaded else { return }
        
        let photos = externalReviewPhotosByPlace[placeId] ?? []
        if currentIndex >= max(0, photos.count - 2) {
            loadExternalReviewPhotos(for: place, reset: false)
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
    
    /// Load image directly from URL
    private func loadImageFromURL(imageUrl: String) async -> UIImage? {
        // ✅ COMPLETE Firebase elimination - block ALL Firebase URLs, only use Supabase
        if imageUrl.contains("firebasestorage.googleapis.com") {
            return nil
        }
        
        guard let url = URL(string: imageUrl) else {
            return nil
        }
        
        do {
            // ✅ Use background queue and shorter timeout
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            config.timeoutIntervalForResource = 10.0
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
    
    // Public method to reload review photos
    func reloadReviewPhotos<T: ReviewProtocol>(for review: T) {
        self.loadReviewPhotos(for: review)
    }
    
    /// Load profile photo from URL (URL comes from SQL JOIN with users table)
    private func loadProfilePhotoFromURL(userId: String, photoUrl: String) {
        // Skip if already loaded or empty URL
        guard !photoUrl.isEmpty, userProfilePhotos[userId] == nil else { return }
        
        Task {
            guard let url = URL(string: photoUrl) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.userProfilePhotos[userId] = image
                        self.detailPlaceViewModel?.userProfilePicture[userId] = image
                        self.profilePhotoLoadingStates[userId] = .loaded
                    }
                }
            } catch {
                // Silently fail - profile photo is optional
                await MainActor.run {
                    self.profilePhotoLoadingStates[userId] = .loaded
                }
            }
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
                    
                    // ✅ Load photos in background with delay to prevent UI blocking
                    Task.detached(priority: .background) { [weak self] in
                        guard let self = self else { return }
                        
                        // Small delay to let UI settle first
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        
                        for comment in fetchedComments where !comment.images.isEmpty {
                            await self.loadCommentPhotos(for: comment)
                        }
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
                
                ReviewService.shared.addComment(reviewId: reviewId, userId: userId, text: comment.commentText, photoUrls: comment.images) { [weak self] result in
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
        
        // ✅ Move to background thread to prevent UI blocking
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            await self.imageService.fetchPhotosFromStorage(urls: comment.images) { [weak self] images, error in
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
            self.loadProfilePhotoFromURL(userId: review.userId, photoUrl: review.profilePhotoUrl)
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
    
    var tiktokVideos: [TikTokVideo] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return placeTikToks[placeId] ?? []
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

    var externalReviewPhotos: [UIImage] {
        guard let placeId = selectedPlace?.id.uuidString else { return [] }
        return externalReviewPhotosByPlace[placeId] ?? []
    }

    var externalReviewPhotoLoadingState: LoadingState {
        guard let placeId = selectedPlace?.id.uuidString else { return .idle }
        return externalReviewPhotoLoadingStates[placeId] ?? .idle
    }

    var externalReviewPhotosFullyLoaded: Bool {
        guard let placeId = selectedPlace?.id.uuidString else { return true }
        return externalReviewPhotosAllLoadedByPlace[placeId] ?? false
    }

    var allPhotosLoadedForCurrentPlace: Bool {
        return allPhotosLoaded
    }
    
    func likeReview<T: ReviewProtocol>(_ review: T, userId: String) {
        // TODO: Implement proper like/unlike logic with Supabase
    }

    // Add helper method to check if a review is liked
    func isReviewLiked(_ reviewId: String) -> Bool {
        return likedReviews.contains(reviewId)
    }
    
    // Load comment count for a review (without loading all comments)
    func loadCommentCountForReview(placeId: String, reviewId: String) {
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
        print("🎬 [SelectedPlaceViewModel] Description: \(description ?? "nil")")
        print("🎬 [SelectedPlaceViewModel] Coordinate: \(coordinate.latitude), \(coordinate.longitude)")
        print("🎬 [SelectedPlaceViewModel] User ID: \(userId)")
        print("🎬 [SelectedPlaceViewModel] ID String: \(idString ?? "nil")")
        
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
        
        print("🎬 [SelectedPlaceViewModel] Created new place with ID: \(newPlace.id.uuidString)")
        print("🎬 [SelectedPlaceViewModel] Place isCustom: \(newPlace.isCustom ?? false)")
        
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
        
        // Test Supabase connection first
        print("🔍 [SelectedPlaceViewModel] Testing Supabase connection...")
        Task { @MainActor in
            SupabasePlaceService.shared.testSupabaseConnection { isConnected, error in
                if !isConnected {
                    print("❌ [SelectedPlaceViewModel] Supabase connection failed: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Save to main places collection
                print("💾 [SelectedPlaceViewModel] Starting to save place to database...")
                self.placeService.addToAllPlaces(place: newPlace) { error in
                    if let error = error {
                        print("❌ [SelectedPlaceViewModel] Error saving place to main collection: \(error.localizedDescription)")
                    } else {
                        print("✅ [SelectedPlaceViewModel] Successfully saved place to main collection")
                        
                        // Save to user's myPlaces collection
                        print("💾 [SelectedPlaceViewModel] Starting to save place to user's myPlaces...")
                        self.placeService.addToMyPlaces(userId: userId, place: newPlace) { error in
                            if let error = error {
                                print("❌ [SelectedPlaceViewModel] Error saving place to user's collection: \(error.localizedDescription)")
                            } else {
                                print("✅ [SelectedPlaceViewModel] Successfully saved place to user's myPlaces collection")
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