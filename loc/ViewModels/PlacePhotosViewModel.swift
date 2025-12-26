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
    
    // MARK: - Review Photos State
    @Published private var reviewPhotos: [String: [UIImage]] = [:] // Cache for review photos by reviewId
    @Published private var reviewPhotoLoadingStates: [String: LoadingState] = [:] // Loading states for review photos
    
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
    
    // MARK: - Deduplication Tracking
    // Tracks URLs that have already been loaded to prevent duplicates
    private var loadedPlacePhotoURLs: [String: Set<String>] = [:]      // placeId -> loaded internal photo URLs
    private var loadedExternalPhotoURLs: [String: Set<String>] = [:]   // placeId -> loaded external photo URLs
    private var externalSeenURLs: [String: Set<String>] = [:]          // placeId -> seen external URLs (for URL cache dedup)
    
    // MARK: - Dependencies
    private let postService: PostService
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
    init(postService: PostService, selectedPlaceVM: SelectedPlaceViewModel) {
        self.postService = postService
        self.selectedPlaceVM = selectedPlaceVM
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe place changes - reset state when place changes
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                guard let self = self else { return }
                self.place = place
                self.placeId = place?.id.uuidString ?? ""
                
                if let place = place {
                    self.resetPhotoLoading()
                    self.loadExternalReviewPhotos(for: place, reset: true)
                }
            }
            .store(in: &cancellables)
        
        // Observe when posts are initially loaded (debounced to wait for posts to arrive)
        selectedPlaceVM.$selectedPlace
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] place in
                guard let self = self, let place = place else { return }
                self.loadPhotosForCurrentPosts(place: place)
            }
            .store(in: &cancellables)
        
        // Observe when posts are added/modified (e.g., after submitting a new post)
        selectedPlaceVM.$postsUpdateCounter
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                guard let self = self, let place = self.place else { return }
                self.loadPhotosForCurrentPosts(place: place)
            }
            .store(in: &cancellables)
    }
    
    /// Loads photos for all current posts - called when posts are loaded or updated
    private func loadPhotosForCurrentPosts(place: DetailPlace) {
        // Load place-level photo gallery from post images
        getPlacePhotos(for: place, loadMore: false)
        
        // Load individual post photos and profile photos
        let posts = selectedPlaceVM.posts
        for post in posts {
            loadPostPhotos(for: post)
            loadProfilePhotoFromURL(userId: post.userId, photoUrl: post.profilePhotoUrl)
        }
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
    
    /// Resets all photo caches and loading states when switching to a new place
    private func resetPhotoLoading() {
        guard let placeId = place?.id.uuidString else { return }
        
        // Reset place-level photo gallery
        placePhotos[placeId]?.removeAll()
        photoLoadingStates[placeId] = .idle
        lastPhotoDocument = nil
        allPhotosLoaded = false
        
        // Reset external review photos
        externalReviewPhotosByPlace.removeValue(forKey: placeId)
        externalReviewPhotoLoadingStates[placeId] = .idle
        externalReviewPhotosAllLoadedByPlace[placeId] = false
        externalReviewImageURLCache[placeId]?.removeAll()
        externalReviewReviewOffsets[placeId] = 0
        externalReviewPhotoCursor[placeId] = 0
        externalReviewReviewHasMore[placeId] = true
        
        // Reset deduplication tracking
        loadedPlacePhotoURLs[placeId]?.removeAll()
        loadedExternalPhotoURLs[placeId]?.removeAll()
        externalSeenURLs[placeId]?.removeAll()
    }
    
    private func getPlacePhotos(for place: DetailPlace, loadMore: Bool = false) {
        let placeId = place.id.uuidString
        
        // Don't fetch if already loading
        if photoLoadingStates[placeId] == .loading && !loadMore {
            return
        }
        
        photoLoadingStates[placeId] = .loading
        
        Task {
            let urlsToFetch = collectUniquePhotoURLs(for: placeId)
            
            // If no new photos to load, mark as complete
            if urlsToFetch.isEmpty {
                self.photoLoadingStates[placeId] = .loaded
                if self.placePhotos[placeId] == nil {
                    self.placePhotos[placeId] = []
                }
                self.allPhotosLoaded = true
                return
            }
            
            // Load images in parallel
            let loadedImages = await loadImagesInParallel(from: urlsToFetch)
            
            // Track loaded URLs and update cache
            markURLsAsLoaded(urlsToFetch, for: placeId, isExternal: false)
            appendPhotos(loadedImages, for: placeId)
            
            self.photoLoadingStates[placeId] = .loaded
        }
    }
    
    // MARK: - Photo Deduplication Helpers
    
    /// Collects unique photo URLs from posts, excluding already-loaded URLs
    /// Single Responsibility: URL collection and deduplication
    private func collectUniquePhotoURLs(for placeId: String) -> [String] {
        let posts = selectedPlaceVM.posts
        let loadedURLs = loadedPlacePhotoURLs[placeId] ?? []
        
        // Use ordered set approach to maintain order while deduplicating
        var seenURLs = Set<String>()
        var uniqueURLs: [String] = []
        
        for post in posts {
            for url in post.images {
                // Skip if already loaded or already seen in this batch
                guard !loadedURLs.contains(url), !seenURLs.contains(url) else { continue }
                seenURLs.insert(url)
                uniqueURLs.append(url)
            }
        }
        
        // Apply page limit
        let limit = min(photoPageLimit, uniqueURLs.count)
        return Array(uniqueURLs.prefix(limit))
    }
    
    /// Marks URLs as loaded to prevent future duplicate loads
    private func markURLsAsLoaded(_ urls: [String], for placeId: String, isExternal: Bool) {
        if isExternal {
            if loadedExternalPhotoURLs[placeId] == nil {
                loadedExternalPhotoURLs[placeId] = []
            }
            loadedExternalPhotoURLs[placeId]?.formUnion(urls)
        } else {
            if loadedPlacePhotoURLs[placeId] == nil {
                loadedPlacePhotoURLs[placeId] = []
            }
            loadedPlacePhotoURLs[placeId]?.formUnion(urls)
        }
    }
    
    /// Appends photos to the cache, maintaining order
    private func appendPhotos(_ images: [UIImage], for placeId: String) {
        if placePhotos[placeId] == nil {
            placePhotos[placeId] = []
        }
        placePhotos[placeId]?.append(contentsOf: images)
    }
    
    /// Loads images in parallel from URLs
    /// Single Responsibility: Parallel image loading
    private func loadImagesInParallel(from urls: [String]) async -> [UIImage] {
        guard !urls.isEmpty else { return [] }
        
        // Use dictionary to maintain URL -> Image mapping for order preservation
        var urlToImage: [String: UIImage] = [:]
        
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for url in urls {
                group.addTask {
                    let image = await self.loadImageFromURL(imageUrl: url)
                    return (url, image)
                }
            }
            
            for await (url, image) in group {
                if let image = image {
                    urlToImage[url] = image
                }
            }
        }
        
        // Return images in original URL order
        return urls.compactMap { urlToImage[$0] }
    }
    
    // MARK: - External Review Photos
    private struct ExternalReviewPaginationState {
        let placeId: String
        var cachedURLs: [String]
        var seenURLs: Set<String>  // Track seen URLs to prevent duplicates
        var reviewOffset: Int
        var hasMoreReviews: Bool
        var photoCursor: Int
    }
    
    private func extendExternalReviewURLs(placeId: String, state: inout ExternalReviewPaginationState) async throws {
        while state.cachedURLs.count < state.photoCursor + externalReviewPhotoBatchSize && state.hasMoreReviews {
            let page = try await postService.fetchExternalReviewMedia(
                placeId: placeId,
                reviewOffset: state.reviewOffset,
                reviewLimit: externalReviewReviewBatchSize
            )
            
            // Deduplicate URLs before adding to cache
            let newUniqueURLs = deduplicateExternalURLs(page.urls, state: &state)
            state.cachedURLs.append(contentsOf: newUniqueURLs)
            state.reviewOffset = page.nextReviewOffset
            state.hasMoreReviews = page.hasMore
        }
    }
    
    /// Deduplicates external review URLs, filtering out already-seen URLs
    /// Single Responsibility: URL deduplication for external reviews
    private func deduplicateExternalURLs(_ urls: [String], state: inout ExternalReviewPaginationState) -> [String] {
        var uniqueURLs: [String] = []
        
        for url in urls {
            guard !state.seenURLs.contains(url) else { continue }
            state.seenURLs.insert(url)
            uniqueURLs.append(url)
        }
        
        return uniqueURLs
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
        
        // Get URLs to load, filtering out already-loaded ones
        let candidateURLs = Array(state.cachedURLs.dropFirst(state.photoCursor).prefix(externalReviewPhotoBatchSize))
        let loadedURLs = loadedExternalPhotoURLs[placeId] ?? []
        let urlsToLoad = candidateURLs.filter { !loadedURLs.contains($0) }
        
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
            // Still advance cursor even if all URLs were already loaded
            state.photoCursor += candidateURLs.count
            updateExternalReviewPaginationState(state, newImages: [], loadingState: .loaded)
        } else {
            let loadedImages = await loadImagesInParallel(from: urlsToLoad)
            state.photoCursor += candidateURLs.count
            
            // Track loaded URLs to prevent future duplicates
            markURLsAsLoaded(urlsToLoad, for: placeId, isExternal: true)
            
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
            externalSeenURLs[placeId] = []
        }
        
        let cachedURLs = externalReviewImageURLCache[placeId] ?? []
        let reviewOffset = externalReviewReviewOffsets[placeId] ?? 0
        let hasMore = externalReviewReviewHasMore[placeId] ?? true
        let cursor = externalReviewPhotoCursor[placeId] ?? 0
        let seenURLs = externalSeenURLs[placeId] ?? []
        
        return ExternalReviewPaginationState(
            placeId: placeId,
            cachedURLs: cachedURLs,
            seenURLs: seenURLs,
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
        externalSeenURLs[state.placeId] = state.seenURLs  // Persist seen URLs for deduplication
        
        let noMorePhotos = !state.hasMoreReviews && state.photoCursor >= state.cachedURLs.count
        externalReviewPhotosAllLoadedByPlace[state.placeId] = noMorePhotos
        externalReviewPhotoLoadingStates[state.placeId] = loadingState
    }
    
    /// Load image directly from URL
    private func loadImageFromURL(imageUrl: String) async -> UIImage? {
        // Block Firebase Storage URLs (migrated to Supabase)
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
    
    // MARK: - Post Photos
    
    /// Load photos for a specific post (loads first 4 initially for performance)
    func loadPostPhotos(for post: PlacePost) {
        let postId = post.id
        guard !post.images.isEmpty else {
            reviewPhotos[postId] = []
            reviewPhotoLoadingStates[postId] = .loaded
            return
        }
        
        reviewPhotoLoadingStates[postId] = .loading
        
        // Load only the first 4 images initially for better performance
        let initialImageCount = min(4, post.images.count)
        let initialImageUrls = Array(post.images.prefix(initialImageCount))
        
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
            
            self.reviewPhotos[postId] = loadedImages
            self.reviewPhotoLoadingStates[postId] = .loaded
        }
    }
    
    /// Load more photos for a specific post when user scrolls
    func loadMorePostPhotos(for postId: String, allImageUrls: [String]) {
        guard let currentPhotos = reviewPhotos[postId],
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
            
            self.reviewPhotos[postId]?.append(contentsOf: newImages)
        }
    }
    
    /// Public method to reload post photos
    func reloadPostPhotos(for post: PlacePost) {
        self.loadPostPhotos(for: post)
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
    
    // MARK: - Public Accessors for Post & Profile Photos
    
    func photos(forPostId postId: String) -> [UIImage] {
        return reviewPhotos[postId] ?? []
    }
    
    func photoLoadingState(forPostId postId: String) -> LoadingState {
        return reviewPhotoLoadingStates[postId] ?? .idle
    }
    
    func profilePhoto(forUserId userId: String) -> UIImage? {
        return userProfilePhotos[userId]
    }
    
    func profilePhotoLoadingState(forUserId userId: String) -> LoadingState {
        return profilePhotoLoadingStates[userId] ?? .idle
    }
}

