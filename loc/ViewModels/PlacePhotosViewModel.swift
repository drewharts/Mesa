//
//  PlacePhotosViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  ViewModel for managing place photos and external review photos
//

import Foundation
import UIKit
import Combine

@MainActor
class PlacePhotosViewModel: ObservableObject {
    // MARK: - Published Properties
    // Place-level photos
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache for place-level photos by placeId
    @Published private var photoLoadingStates: [String: LoadingState] = [:] // Loading states for place photos
    @Published private var photoPageLimit = 9
    @Published private var lastPhotoDocument: Any? // Replaced DocumentSnapshot for Supabase migration
    @Published private var allPhotosLoaded = false
    
    // Review photos
    @Published private var reviewPhotos: [String: [UIImage]] = [:] // Cache for review photos by reviewId
    @Published private var reviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for review photos
    @Published private var reviewPhotosForAbout: [String: [UIImage]] = [:] // Cache for review photos in about section by placeId
    @Published private var reviewPhotosForAboutLoadingStates: [String: LoadingState] = [:] // Loading states for review photos in about section
    
    // External review photos
    @Published private var externalReviewPhotosByPlace: [String: [UIImage]] = [:] // Cache for external review photos by placeId
    @Published private var externalReviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for external review photos
    @Published private var externalReviewPhotosAllLoadedByPlace: [String: Bool] = [:] // Track completion of external photo loading per place
    
    // Profile photos
    @Published private var userProfilePhotos: [String: UIImage] = [:] // Cache for profile photos by userId
    @Published private var profilePhotoLoadingStates: [String: LoadingState] = [:] // Loading states for profile photos
    
    @Published var place: DetailPlace?
    @Published var placeId: String = ""
    
    // MARK: - Private Properties
    private var externalReviewImageURLCache: [String: [String]] = [:] // placeId -> photo URLs
    private var externalReviewReviewOffsets: [String: Int] = [:] // placeId -> offset into external reviews
    private var externalReviewPhotoCursor: [String: Int] = [:] // placeId -> number of image URLs consumed
    private var externalReviewReviewHasMore: [String: Bool] = [:] // placeId -> more review pages available
    private var externalReviewRetryAttempts: [String: Int] = [:] // placeId -> retry attempt count
    private let externalReviewReviewBatchSize = 10
    private let externalReviewPhotoBatchSize = 5
    private let maxExternalReviewRetries = 3 // Maximum retry attempts for external reviews
    private let externalReviewRetryDelay: TimeInterval = 2.0 // Delay between retries in seconds
    
    // MARK: - Dependencies
    private let reviewService: ReviewService
    private let selectedPlaceVM: SelectedPlaceViewModel  // Temporary until fully refactored
    private var cancellables = Set<AnyCancellable>()
    
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
    
    // MARK: - Initialization
    init(reviewService: ReviewService, selectedPlaceVM: SelectedPlaceViewModel) {
        self.reviewService = reviewService
        self.selectedPlaceVM = selectedPlaceVM
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe place changes
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                guard let self = self else { return }
                self.place = place
                self.placeId = place?.id.uuidString ?? ""
                
                // Reset and load photos for new place
                if let place = place {
                    self.resetPhotoLoading()
                    // Place photos will be loaded after reviews are ready
                    self.loadExternalReviewPhotos(for: place, reset: true)
                }
            }
            .store(in: &cancellables)
        
        // Observe when reviews are loaded and load photos for them
        // We check selectedPlace changes as proxy for review updates since reviews are loaded after place selection
        selectedPlaceVM.$selectedPlace
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] place in
                guard let self = self, let place = place else { return }
                
                // Load place-level photos from reviews
                self.getPlacePhotos(for: place, loadMore: false)
                
                // Load photos for About section
                self.loadReviewPhotosForAbout(for: place)
                
                // Load review photos and profile photos for each review
                let reviews = self.selectedPlaceVM.reviews
                reviews.forEach { review in
                    self.loadReviewPhotos(for: review)
                    self.loadProfilePhotoFromURL(userId: review.userId, photoUrl: review.profilePhotoUrl)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Computed Properties
    var photos: [UIImage] {
        guard let placeId = place?.id.uuidString else { return [] }
        return placePhotos[placeId] ?? []
    }
    
    var photoLoadingState: LoadingState {
        guard let placeId = place?.id.uuidString else { return .idle }
        return photoLoadingStates[placeId] ?? .idle
    }
    
    var externalReviewPhotos: [UIImage] {
        guard let placeId = place?.id.uuidString else { return [] }
        return externalReviewPhotosByPlace[placeId] ?? []
    }
    
    var externalReviewPhotoLoadingState: LoadingState {
        guard let placeId = place?.id.uuidString else { return .idle }
        return externalReviewPhotoLoadingStates[placeId] ?? .idle
    }
    
    var externalReviewPhotosFullyLoaded: Bool {
        guard let placeId = place?.id.uuidString else { return true }
        return externalReviewPhotosAllLoadedByPlace[placeId] ?? false
    }
    
    var allPhotosLoadedForCurrentPlace: Bool {
        return allPhotosLoaded
    }
    
    // MARK: - Public Methods
    func loadMorePhotos() {
        guard let place = place, !allPhotosLoaded else {
            return
        }
        
        getPlacePhotos(for: place, loadMore: true)
    }
    
    func loadInitialExternalReviewPhotos() {
        guard let place = place else { return }
        let placeId = place.id.uuidString
        
        // Only skip if we already have photos loaded or are currently loading
        let existingPhotos = externalReviewPhotosByPlace[placeId] ?? []
        let loadingState = externalReviewPhotoLoadingStates[placeId] ?? .idle
        
        if !existingPhotos.isEmpty || loadingState == .loading {
            return
        }
        
        loadExternalReviewPhotos(for: place, reset: false)
    }
    
    func loadMoreExternalReviewPhotosIfNeeded(currentIndex: Int) {
        guard let place = place else { return }
        let placeId = place.id.uuidString
        
        // Early exit if already fully loaded
        guard !externalReviewPhotosFullyLoaded else { return }
        
        let photos = externalReviewPhotosByPlace[placeId] ?? []
        let loadingState = externalReviewPhotoLoadingStates[placeId] ?? .idle
        let triggerThreshold = max(0, photos.count - 2)
        
        // Only trigger if:
        // 1. We're near the end (within last 2 photos)
        // 2. We have at least 3 photos (prevents premature triggers)
        // 3. Not currently loading (prevents duplicate requests)
        if currentIndex >= triggerThreshold && photos.count >= 3 && loadingState != .loading {
            loadExternalReviewPhotos(for: place, reset: false)
        }
    }
    
    // MARK: - Private Methods
    private func resetPhotoLoading() {
        if let placeId = place?.id.uuidString {
            placePhotos[placeId]?.removeAll()
            photoLoadingStates[placeId] = .idle
            reviewPhotosForAbout[placeId]?.removeAll()
            reviewPhotosForAboutLoadingStates[placeId] = .idle
            lastPhotoDocument = nil
            allPhotosLoaded = false
            // Remove the entry entirely instead of just clearing it, so loadInitialExternalReviewPhotos can work
            externalReviewPhotosByPlace.removeValue(forKey: placeId)
            externalReviewPhotoLoadingStates[placeId] = .idle
            externalReviewPhotosAllLoadedByPlace[placeId] = false
            externalReviewImageURLCache[placeId]?.removeAll()
            externalReviewReviewOffsets[placeId] = 0
            externalReviewPhotoCursor[placeId] = 0
            externalReviewReviewHasMore[placeId] = true
        }
    }
    
    private func getPlacePhotos(for place: DetailPlace, loadMore: Bool = false) {
        let placeId = place.id.uuidString
        
        // Don't fetch if already loading
        if photoLoadingStates[placeId] == .loading && !loadMore {
            return
        }
        
        photoLoadingStates[placeId] = .loading
        
        // Use cached reviews to get photos (reviews are already loaded at this point)
        Task {
            let reviews = selectedPlaceVM.reviews
            
            var photoURLs: [String] = []
            for review in reviews {
                photoURLs.append(contentsOf: review.images)
            }
            
            // If no photos found in any reviews, mark as loaded
            if photoURLs.isEmpty {
                self.photoLoadingStates[placeId] = .loaded
                self.placePhotos[placeId] = []
                self.allPhotosLoaded = true
                return
            }
            
            // Paginate the photo URLs
            let startIndex = self.placePhotos[placeId]?.count ?? 0
            let endIndex = min(startIndex + self.photoPageLimit, photoURLs.count)
            
            guard startIndex < endIndex else {
                // No more photos to load
                self.allPhotosLoaded = true
                self.photoLoadingStates[placeId] = .loaded
                return
            }
            
            let urlsToFetch = Array(photoURLs[startIndex..<endIndex])
            
            // Load images in parallel using TaskGroup
            var loadedImages: [UIImage] = []
            
            await withTaskGroup(of: UIImage?.self) { group in
                for url in urlsToFetch {
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
            
            // Update cache with new images
            var currentPhotos = self.placePhotos[placeId] ?? []
            currentPhotos.append(contentsOf: loadedImages)
            self.placePhotos[placeId] = currentPhotos
            
            // Update loading state
            self.photoLoadingStates[placeId] = .loaded
            
            // Check if all photos are loaded
            if endIndex >= photoURLs.count {
                self.allPhotosLoaded = true
            }
        }
    }
    
    // MARK: - External Review Photos
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
        
        // Check AND set loading state BEFORE creating Task to prevent race conditions
        if externalReviewPhotoLoadingStates[placeId] == .loading {
            return
        }
        
        // Set loading state immediately to prevent duplicate requests
        externalReviewPhotoLoadingStates[placeId] = .loading
        
        Task {
            await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: reset)
        }
    }
    
    /// Internal method that handles loading external reviews with retry logic
    private func loadExternalReviewPhotosInternal(for place: DetailPlace, placeId: String, reset: Bool) async {
        if reset {
            self.externalReviewRetryAttempts[placeId] = 0
        }
        
        var state = externalReviewPaginationState(for: placeId, reset: reset)
        
        do {
            try await extendExternalReviewURLs(placeId: placeId, state: &state)
        } catch {
            self.externalReviewPhotoLoadingStates[placeId] = .error(error)
            return
        }
        
        let urlsToLoad = Array(state.cachedURLs.dropFirst(state.photoCursor).prefix(externalReviewPhotoBatchSize))
        
        // If no reviews found and we're still within retry limit, retry
        if urlsToLoad.isEmpty && state.cachedURLs.isEmpty && !state.hasMoreReviews {
            let retryCount = self.externalReviewRetryAttempts[placeId] ?? 0
            
            if retryCount < maxExternalReviewRetries {
                self.externalReviewRetryAttempts[placeId] = retryCount + 1
                
                try? await Task.sleep(nanoseconds: UInt64(externalReviewRetryDelay * 1_000_000_000))
                await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: false)
                return
            } else {
                print("⚠️ [PlacePhotosViewModel] No external reviews after \(maxExternalReviewRetries) retries for \(placeId)")
            }
        }
        
        // Load images if we have URLs, otherwise mark as loaded (empty state)
        if urlsToLoad.isEmpty {
            updateExternalReviewPaginationState(state, newImages: [], loadingState: .loaded)
        } else {
            let loadedImages = await loadExternalReviewImages(from: urlsToLoad)
            state.photoCursor += urlsToLoad.count
            
            // Reset retry count on success
            self.externalReviewRetryAttempts[placeId] = 0
            
            updateExternalReviewPaginationState(state, newImages: loadedImages, loadingState: .loaded)
        }
    }
    
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
            print("Error loading image from URL: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Review Photos
    
    /// Load photos for a specific review (loads first 4 initially for performance)
    func loadReviewPhotos<T: ReviewProtocol>(for review: T) {
        let reviewId = review.id
        guard !review.images.isEmpty else {
            reviewPhotos[reviewId] = []
            reviewPhotoLoadingStates[reviewId] = .loaded
            return
        }
        
        reviewPhotoLoadingStates[reviewId] = .loading
        
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
                    if let image {
                        loadedImages.append(image)
                    }
                }
            }
            
            self.reviewPhotos[reviewId] = loadedImages
            self.reviewPhotoLoadingStates[reviewId] = .loaded
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
        
        Task {
            var newImages: [UIImage] = []
            
            await withTaskGroup(of: UIImage?.self) { group in
                for imageUrl in urlsToLoad {
                    group.addTask {
                        await self.loadImageFromURL(imageUrl: imageUrl)
                    }
                }
                
                for await image in group {
                    if let image {
                        newImages.append(image)
                    }
                }
            }
            
            self.reviewPhotos[reviewId]?.append(contentsOf: newImages)
        }
    }
    
    /// Public method to reload review photos
    func reloadReviewPhotos<T: ReviewProtocol>(for review: T) {
        self.loadReviewPhotos(for: review)
    }
    
    /// Load photos for the About section (limited to first 6 for performance)
    func loadReviewPhotosForAbout(for place: DetailPlace) {
        let placeId = place.id.uuidString
        
        // Don't fetch if already loading
        if reviewPhotosForAboutLoadingStates[placeId] == .loading {
            return
        }
        
        reviewPhotosForAboutLoadingStates[placeId] = .loading
        
        // Use cached reviews to get photo URLs (reviews are already loaded at this point)
        Task {
            let reviews = selectedPlaceVM.reviews
            
            // Extract photo URLs from reviews
            var photoURLs: [String] = []
            for review in reviews {
                photoURLs.append(contentsOf: review.images)
            }
            
            // If no photos found, mark as loaded with empty array
            if photoURLs.isEmpty {
                self.reviewPhotosForAbout[placeId] = []
                self.reviewPhotosForAboutLoadingStates[placeId] = .loaded
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
                    if let image {
                        loadedImages.append(image)
                    }
                }
            }
            
            self.reviewPhotosForAbout[placeId] = loadedImages
            self.reviewPhotosForAboutLoadingStates[placeId] = .loaded
        }
    }
    
    // MARK: - Profile Photos
    
    /// Load profile photo from URL (URL comes from SQL JOIN with users table)
    func loadProfilePhotoFromURL(userId: String, photoUrl: String) {
        // Skip if already loaded or empty URL
        guard !photoUrl.isEmpty, userProfilePhotos[userId] == nil else { return }
        
        Task {
            guard let url = URL(string: photoUrl) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    self.userProfilePhotos[userId] = image
                    self.profilePhotoLoadingStates[userId] = .loaded
                }
            } catch {
                // Silently fail - profile photo is optional
                self.profilePhotoLoadingStates[userId] = .loaded
            }
        }
    }
    
    // MARK: - Public Accessors for Review & Profile Photos
    
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
    
    func reviewPhotosForAbout(forPlaceId placeId: String) -> [UIImage] {
        return reviewPhotosForAbout[placeId] ?? []
    }
    
    func reviewPhotosForAboutLoadingState(forPlaceId placeId: String) -> LoadingState {
        return reviewPhotosForAboutLoadingStates[placeId] ?? .idle
    }
}

