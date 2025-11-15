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
    @Published private var placePhotos: [String: [UIImage]] = [:] // Cache for place-level photos by placeId
    @Published private var photoLoadingStates: [String: LoadingState] = [:] // Loading states for place photos
    @Published private var externalReviewPhotosByPlace: [String: [UIImage]] = [:] // Cache for external review photos by placeId
    @Published private var externalReviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for external review photos
    @Published private var externalReviewPhotosAllLoadedByPlace: [String: Bool] = [:] // Track completion of external photo loading per place
    @Published private var photoPageLimit = 9
    @Published private var lastPhotoDocument: Any? // Replaced DocumentSnapshot for Supabase migration
    @Published private var allPhotosLoaded = false
    
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
                    self.getPlacePhotos(for: place, loadMore: false)
                    self.loadExternalReviewPhotos(for: place, reset: true)
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
        
        guard !externalReviewPhotosFullyLoaded else { return }
        
        let photos = externalReviewPhotosByPlace[placeId] ?? []
        if currentIndex >= max(0, photos.count - 2) {
            loadExternalReviewPhotos(for: place, reset: false)
        }
    }
    
    // MARK: - Private Methods
    private func resetPhotoLoading() {
        if let placeId = place?.id.uuidString {
            placePhotos[placeId]?.removeAll()
            photoLoadingStates[placeId] = .idle
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
        
        if externalReviewPhotoLoadingStates[placeId] == .loading {
            return
        }
        
        Task {
            await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: reset)
        }
    }
    
    /// Internal method that handles loading external reviews with retry logic
    private func loadExternalReviewPhotosInternal(for place: DetailPlace, placeId: String, reset: Bool) async {
        self.externalReviewPhotoLoadingStates[placeId] = .loading
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
                print("🔄 [PlacePhotosViewModel] No external reviews for \(placeId), retrying (\(retryCount + 1)/\(maxExternalReviewRetries))...")
                
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
}

