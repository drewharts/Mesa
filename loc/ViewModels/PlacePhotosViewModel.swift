//
//  PlacePhotosViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  ViewModel for managing place photos and external review photos
//  Data-Driven: Receives place/posts data via setPlace()/setPosts() instead of observing ViewModels
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

    // MARK: - 403 Error Tracking for Image Refresh
    // Tracks failed Google CDN URLs that returned 403 (expired)
    private var failedExternalURLs: [String: Set<String>] = [:]        // placeId -> failed URLs
    private var refreshRequestedForPlace: Set<String> = []              // Places that have already requested refresh this session

    // MARK: - Image Refresh State
    @Published private var isRefreshingImagesByPlace: [String: Bool] = [:] // Tracks active refresh operations per place

    // MARK: - Dependencies (Services only)
    private let postService: PostService

    // Store current posts for photo loading
    private var currentPosts: [PlacePost] = []

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
    init() {
        self.postService = ServiceContainer.shared.postService
    }

    // MARK: - Data-Driven Updates

    /// Called by parent when the selected place changes
    func setPlace(_ place: DetailPlace?) {
        self.place = place
        self.placeId = place?.id.uuidString ?? ""

        if let place = place {
            print("📸 [PlacePhotosViewModel] setPlace called for: \(place.id.uuidString)")
            resetPhotoLoading()
            loadExternalReviewPhotos(for: place, reset: true)
        }
    }

    /// Called by parent when posts are loaded or updated
    func setPosts(_ posts: [PlacePost]) {
        self.currentPosts = posts
        guard let place = place else { return }
        loadPhotosForCurrentPosts(place: place, posts: posts)
    }

    /// Loads photos for all current posts - called when posts are loaded or updated
    private func loadPhotosForCurrentPosts(place: DetailPlace, posts: [PlacePost]) {
        // Load place-level photo gallery from post images
        getPlacePhotos(for: place, loadMore: false)

        // Load individual post photos and profile photos
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

    /// Indicates whether external review images are currently being refreshed after 403 errors.
    var isRefreshingImages: Bool {
        guard let placeId = place?.id.uuidString else { return false }
        return isRefreshingImagesByPlace[placeId] ?? false
    }

    /// Combined photos from both internal reviews and external sources
    var combinedPhotos: [UIImage] {
        let internalPhotos = photos
        let external = externalReviewPhotos
        return internalPhotos + external
    }

    /// Total count of all available photos (for "+X more" indicator)
    var totalPhotoCount: Int {
        return photos.count + externalReviewPhotos.count
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
        let posts = currentPosts
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

        if let firstUrl = urls.first {
            print("📸 [PlacePhotosViewModel] First URL to load: \(firstUrl.prefix(80))...")
        }

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
                } else {
                    print("📸 [PlacePhotosViewModel] Failed to load image from: \(url.prefix(60))...")
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
            print("📸 [PlacePhotosViewModel] Skipping loadExternalReviewPhotos - already loading for \(placeId)")
            return
        }

        print("📸 [PlacePhotosViewModel] Starting loadExternalReviewPhotos for \(placeId), reset=\(reset)")

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
            print("📸 [PlacePhotosViewModel] After extendExternalReviewURLs: cachedURLs=\(state.cachedURLs.count), hasMore=\(state.hasMoreReviews)")
        } catch {
            print("📸 [PlacePhotosViewModel] Error extending URLs: \(error)")
            self.externalReviewPhotoLoadingStates[placeId] = .error(error)
            return
        }

        // Get URLs to load, filtering out already-loaded ones
        let candidateURLs = Array(state.cachedURLs.dropFirst(state.photoCursor).prefix(externalReviewPhotoBatchSize))
        let loadedURLs = loadedExternalPhotoURLs[placeId] ?? []
        let urlsToLoad = candidateURLs.filter { !loadedURLs.contains($0) }
        print("📸 [PlacePhotosViewModel] candidateURLs=\(candidateURLs.count), urlsToLoad=\(urlsToLoad.count)")
        
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
            print("📸 [PlacePhotosViewModel] No URLs to load, marked as loaded")
        } else {
            print("📸 [PlacePhotosViewModel] Loading \(urlsToLoad.count) images in parallel...")
            let loadedImages = await loadImagesInParallel(from: urlsToLoad)
            print("📸 [PlacePhotosViewModel] Successfully loaded \(loadedImages.count) images")
            state.photoCursor += candidateURLs.count

            // Track loaded URLs to prevent future duplicates
            markURLsAsLoaded(urlsToLoad, for: placeId, isExternal: true)

            // Reset retry count on success
            self.externalReviewRetryAttempts[placeId] = 0

            updateExternalReviewPaginationState(state, newImages: loadedImages, loadingState: .loaded)
            print("📸 [PlacePhotosViewModel] Updated pagination state, total external photos: \(externalReviewPhotosByPlace[state.placeId]?.count ?? 0)")

            // Check if we had significant 403 failures and should request image refresh
            let failedCount = failedExternalURLs[placeId]?.count ?? 0
            let totalAttempted = urlsToLoad.count
            let successCount = loadedImages.count

            // If more than half the images failed and we have 403 errors, request refresh
            if failedCount > 0 && successCount < totalAttempted / 2 {
                await requestImageRefreshIfNeeded(for: placeId)
            }
        }
    }

    /// Requests the backend to refresh stale external review images if needed.
    private func requestImageRefreshIfNeeded(for placeId: String) async {
        // Check if we have failed URLs for this place
        guard let failedURLs = failedExternalURLs[placeId], !failedURLs.isEmpty else {
            return
        }

        // Rate limit: only request once per place per session
        guard !refreshRequestedForPlace.contains(placeId) else {
            print("📸 [PlacePhotosViewModel] Already requested refresh for place \(placeId) this session")
            return
        }

        refreshRequestedForPlace.insert(placeId)

        // Show refresh indicator immediately so users know images are being refreshed
        isRefreshingImagesByPlace[placeId] = true

        print("📸 [PlacePhotosViewModel] Requesting image refresh for place \(placeId) with \(failedURLs.count) failed URLs")

        do {
            let mesaBackendService = MesaBackendService.shared
            let refreshInitiated = try await mesaBackendService.requestImageRefresh(
                placeId: placeId,
                failedURLs: Array(failedURLs)
            )

            if refreshInitiated {
                print("📸 [PlacePhotosViewModel] Refresh initiated, waiting 3s before retrying...")

                // Shorter delay since we're showing existing images with a refresh indicator
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

                // Clear only failed URLs, keep successful images visible
                failedExternalURLs[placeId]?.removeAll()

                // Retry loading external photos (appends new images to existing ones)
                await retryExternalPhotosAfterRefresh(for: placeId)
            } else {
                print("📸 [PlacePhotosViewModel] No refresh needed or rate limited")
            }
        } catch {
            print("📸 [PlacePhotosViewModel] Failed to request image refresh: \(error)")
        }

        // Hide refresh indicator when done
        isRefreshingImagesByPlace[placeId] = false
    }

    /// Retries loading external photos after backend has refreshed the image URLs.
    private func retryExternalPhotosAfterRefresh(for placeId: String) async {
        guard let place = place, place.id.uuidString == placeId else { return }

        print("📸 [PlacePhotosViewModel] Retrying external photos after refresh for \(placeId)")

        // Keep existing successful photos - don't clear externalReviewPhotosByPlace[placeId]
        // Only reset URL caches to fetch fresh URLs from the database
        externalReviewImageURLCache[placeId] = []
        externalReviewReviewOffsets[placeId] = 0
        externalReviewPhotoCursor[placeId] = 0
        externalReviewReviewHasMore[placeId] = true
        externalReviewPhotosAllLoadedByPlace[placeId] = false
        loadedExternalPhotoURLs[placeId]?.removeAll()
        externalSeenURLs[placeId]?.removeAll()

        // Reload - new images will be appended to existing successful ones
        await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: false)
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
    
    /// Transform Google CDN URL to request higher resolution
    /// Google's lh3.googleusercontent.com URLs support size parameters like =s1600
    private func getHighResGoogleURL(_ imageUrl: String, maxSize: Int = 1600) -> String {
        guard imageUrl.contains("lh3.googleusercontent.com") else {
            return imageUrl
        }

        // Remove existing size parameters (=s123, =w123-h456, etc.)
        var baseUrl = imageUrl
        if let range = baseUrl.range(of: "=s\\d+.*$", options: .regularExpression) {
            baseUrl.removeSubrange(range)
        }
        if let range = baseUrl.range(of: "=w\\d+-h\\d+.*$", options: .regularExpression) {
            baseUrl.removeSubrange(range)
        }

        return "\(baseUrl)=s\(maxSize)"
    }

    /// Load image directly from URL
    private func loadImageFromURL(imageUrl: String) async -> UIImage? {
        // Block legacy storage URLs that are no longer accessible
        if imageUrl.contains("firebasestorage.googleapis.com") {
            print("📸 [PlacePhotosViewModel] Blocked Firebase URL: \(imageUrl.prefix(50))...")
            return nil
        }

        // Request higher resolution for Google CDN images
        let highResUrl = getHighResGoogleURL(imageUrl, maxSize: 1600)

        guard let url = URL(string: highResUrl) else {
            print("📸 [PlacePhotosViewModel] Invalid URL string: \(highResUrl.prefix(50))...")
            return nil
        }

        do {
            // ✅ Use background queue and shorter timeout
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            config.timeoutIntervalForResource = 10.0
            let session = URLSession(configuration: config)

            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("📸 [PlacePhotosViewModel] HTTP \(httpResponse.statusCode) for URL: \(imageUrl.prefix(50))...")

                // Track 403 errors on Google CDN URLs for potential refresh
                if httpResponse.statusCode == 403 && imageUrl.contains("googleusercontent.com") {
                    trackFailed403URL(imageUrl)
                }

                return nil
            }
            guard let image = UIImage(data: data) else {
                print("📸 [PlacePhotosViewModel] Could not create UIImage from data (\(data.count) bytes)")
                return nil
            }
            return image
        } catch {
            print("📸 [PlacePhotosViewModel] Error loading image: \(error.localizedDescription)")
            return nil
        }
    }

    /// Tracks a URL that returned 403 Forbidden (expired Google CDN URL)
    private func trackFailed403URL(_ url: String) {
        guard let currentPlaceId = place?.id.uuidString else { return }

        if failedExternalURLs[currentPlaceId] == nil {
            failedExternalURLs[currentPlaceId] = []
        }
        failedExternalURLs[currentPlaceId]?.insert(url)

        print("📸 [PlacePhotosViewModel] Tracked 403 error for URL (place: \(currentPlaceId)): \(url.prefix(60))...")
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

