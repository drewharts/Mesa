//
//  ExternalReviewPhotosViewModel.swift
//  loc
//
//  Manages external review photo loading, pagination, retry logic, and expired URL recovery.
//  Extracted from PlacePhotosViewModel for single-responsibility compliance.
//

import Foundation
import UIKit

@MainActor
class ExternalReviewPhotosViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private var externalReviewPhotoItems: [String: [PhotoItem]] = [:]
    @Published private var externalReviewPhotoLoadingStates: [String: LoadingState] = [:]
    @Published private var externalReviewPhotosAllLoadedByPlace: [String: Bool] = [:]
    @Published private var isRefreshingImagesByPlace: [String: Bool] = [:]

    // MARK: - Private Pagination State
    private var externalReviewImageURLCache: [String: [String]] = [:]
    private var externalReviewReviewOffsets: [String: Int] = [:]
    private var externalReviewPhotoCursor: [String: Int] = [:]
    private var externalReviewReviewHasMore: [String: Bool] = [:]
    private var externalReviewRetryAttempts: [String: Int] = [:]
    private let externalReviewReviewBatchSize = 10
    private let externalReviewPhotoBatchSize = 10
    private let maxExternalReviewRetries = 3
    private let externalReviewRetryDelay: TimeInterval = 2.0

    // MARK: - Deduplication
    private var loadedExternalPhotoURLs: [String: Set<String>] = [:]
    private var externalSeenURLs: [String: Set<String>] = [:]

    // MARK: - Google CDN Validation Tracking
    private var googleCDNCheckedForPlace: Set<String> = []
    private var refreshRequestedForPlace: Set<String> = []

    // MARK: - Per-Image Failure Tracking
    private var failedImageURLs: [String: Set<String>] = [:]
    private var perImageRefreshAttempted: Set<String> = []
    private var pendingFailureRefreshTask: Task<Void, Never>?
    private var backgroundValidationStarted: Set<String> = []

    // MARK: - Dependencies
    private let postService: PostService

    // MARK: - Current Place
    private var place: DetailPlace?

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
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Initialization
    init() {
        self.postService = ServiceContainer.shared.postService
    }

    // MARK: - Public Computed Properties

    /// External review photo items for the current place.
    var externalPhotoItems: [PhotoItem] {
        guard let placeId = place?.id.uuidString else { return [] }
        return externalReviewPhotoItems[placeId] ?? []
    }

    /// Loading state for external review photos.
    var externalReviewPhotoLoadingState: LoadingState {
        guard let placeId = place?.id.uuidString else { return .idle }
        return externalReviewPhotoLoadingStates[placeId] ?? .idle
    }

    /// Whether all external review photos have been loaded for the current place.
    var externalReviewPhotosFullyLoaded: Bool {
        guard let placeId = place?.id.uuidString else { return true }
        return externalReviewPhotosAllLoadedByPlace[placeId] ?? false
    }

    /// Whether external review images are currently being refreshed after 403 errors.
    var isRefreshingImages: Bool {
        guard let placeId = place?.id.uuidString else { return false }
        return isRefreshingImagesByPlace[placeId] ?? false
    }

    // MARK: - Public Methods

    /// Updates the current place reference and resets/loads external photos.
    func setPlace(_ place: DetailPlace?) {
        self.place = place
        guard let place = place, !place.hasPlaceholderID else { return }
        resetState(for: place.id.uuidString)
        loadExternalReviewPhotos(for: place, reset: true)
    }

    /// Resets state without triggering a new load (used during coordinator reset).
    func resetForNewPlace(_ place: DetailPlace?) {
        self.place = place
        guard let placeId = place?.id.uuidString else { return }
        resetState(for: placeId)
    }

    /// Loads initial external review photos if not already loaded.
    func loadInitialExternalReviewPhotos() {
        guard let place = place else { return }
        let placeId = place.id.uuidString

        let existingItems = externalReviewPhotoItems[placeId] ?? []
        let loadingState = externalReviewPhotoLoadingStates[placeId] ?? .idle

        if !existingItems.isEmpty || loadingState == .loading {
            return
        }

        loadExternalReviewPhotos(for: place, reset: false)
    }

    /// Loads more external review photos when nearing the end of the list.
    func loadMoreExternalReviewPhotosIfNeeded(currentIndex: Int) {
        guard let place = place else { return }
        let placeId = place.id.uuidString

        guard !externalReviewPhotosFullyLoaded else { return }

        let items = externalReviewPhotoItems[placeId] ?? []
        let loadingState = externalReviewPhotoLoadingStates[placeId] ?? .idle
        let triggerThreshold = max(0, items.count - 2)

        if currentIndex >= triggerThreshold && items.count >= 3 && loadingState != .loading {
            loadExternalReviewPhotos(for: place, reset: false)
        }
    }

    /// Deletes an external review photo optimistically, then calls the backend RPC.
    func deletePhoto(url: String) async {
        guard let placeId = place?.id.uuidString else { return }

        let removedItem = externalReviewPhotoItems[placeId]?.first { $0.url == url }
        let removedIndex = externalReviewPhotoItems[placeId]?.firstIndex { $0.url == url }

        // Optimistic removal
        externalReviewPhotoItems[placeId]?.removeAll { $0.url == url }
        loadedExternalPhotoURLs[placeId]?.remove(url)
        externalSeenURLs[placeId]?.remove(url)
        externalReviewImageURLCache[placeId]?.removeAll { $0 == url }

        do {
            try await postService.deleteExternalReviewImage(placeId: placeId, imageUrl: url)
            print("📸 [ExternalReviewPhotosVM] Deleted external review image: \(url.prefix(60))...")
        } catch {
            print("📸 [ExternalReviewPhotosVM] Failed to delete image, restoring: \(error)")
            // Re-insert at original position on failure
            if let item = removedItem, let index = removedIndex {
                let safeIndex = min(index, externalReviewPhotoItems[placeId]?.count ?? 0)
                externalReviewPhotoItems[placeId]?.insert(item, at: safeIndex)
                loadedExternalPhotoURLs[placeId]?.insert(url)
                externalSeenURLs[placeId]?.insert(url)
            }
        }
    }

    // MARK: - Private Methods

    /// Resets all external review photo state for a given place ID.
    private func resetState(for placeId: String) {
        externalReviewPhotoItems.removeValue(forKey: placeId)
        externalReviewPhotoLoadingStates[placeId] = .idle
        externalReviewPhotosAllLoadedByPlace[placeId] = false
        externalReviewImageURLCache[placeId]?.removeAll()
        externalReviewReviewOffsets[placeId] = 0
        externalReviewPhotoCursor[placeId] = 0
        externalReviewReviewHasMore[placeId] = true
        loadedExternalPhotoURLs[placeId]?.removeAll()
        externalSeenURLs[placeId]?.removeAll()
        failedImageURLs.removeValue(forKey: placeId)
        perImageRefreshAttempted.remove(placeId)
        backgroundValidationStarted.remove(placeId)
        pendingFailureRefreshTask?.cancel()
        pendingFailureRefreshTask = nil
    }

    // MARK: - Pagination State

    private struct PaginationState {
        let placeId: String
        var cachedURLs: [String]
        var seenURLs: Set<String>
        var reviewOffset: Int
        var hasMoreReviews: Bool
        var photoCursor: Int
    }

    /// Creates pagination state for external review photo loading.
    private func createPaginationState(for placeId: String, reset: Bool) -> PaginationState {
        if reset {
            externalReviewPhotoItems[placeId] = []
            externalReviewImageURLCache[placeId] = []
            externalReviewReviewOffsets[placeId] = 0
            externalReviewPhotoCursor[placeId] = 0
            externalReviewReviewHasMore[placeId] = true
            externalReviewPhotosAllLoadedByPlace[placeId] = false
            externalSeenURLs[placeId] = []
        }

        return PaginationState(
            placeId: placeId,
            cachedURLs: externalReviewImageURLCache[placeId] ?? [],
            seenURLs: externalSeenURLs[placeId] ?? [],
            reviewOffset: externalReviewReviewOffsets[placeId] ?? 0,
            hasMoreReviews: externalReviewReviewHasMore[placeId] ?? true,
            photoCursor: externalReviewPhotoCursor[placeId] ?? 0
        )
    }

    /// Persists pagination state after loading.
    private func persistPaginationState(_ state: PaginationState, loadingState: LoadingState) {
        if externalReviewPhotoItems[state.placeId] == nil {
            externalReviewPhotoItems[state.placeId] = []
        }

        externalReviewImageURLCache[state.placeId] = state.cachedURLs
        externalReviewReviewOffsets[state.placeId] = state.reviewOffset
        externalReviewReviewHasMore[state.placeId] = state.hasMoreReviews
        externalReviewPhotoCursor[state.placeId] = state.photoCursor
        externalSeenURLs[state.placeId] = state.seenURLs

        let noMorePhotos = !state.hasMoreReviews && state.photoCursor >= state.cachedURLs.count
        externalReviewPhotosAllLoadedByPlace[state.placeId] = noMorePhotos
        externalReviewPhotoLoadingStates[state.placeId] = loadingState
    }

    // MARK: - Loading

    /// Starts loading external review photos for a place.
    private func loadExternalReviewPhotos(for place: DetailPlace, reset: Bool) {
        let placeId = place.id.uuidString

        if externalReviewPhotoLoadingStates[placeId] == .loading {
            print("📸 [ExternalReviewPhotosVM] Skipping - already loading for \(placeId)")
            return
        }

        print("📸 [ExternalReviewPhotosVM] Starting load for \(placeId), reset=\(reset)")
        externalReviewPhotoLoadingStates[placeId] = .loading

        Task {
            await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: reset)
        }
    }

    /// Fetches external review URLs and creates PhotoItems.
    private func loadExternalReviewPhotosInternal(for place: DetailPlace, placeId: String, reset: Bool) async {
        if reset {
            self.externalReviewRetryAttempts[placeId] = 0
        }

        var state = createPaginationState(for: placeId, reset: reset)

        do {
            try await extendURLCache(placeId: placeId, state: &state)
        } catch {
            print("📸 [ExternalReviewPhotosVM] Error extending URLs: \(error)")
            self.externalReviewPhotoLoadingStates[placeId] = .error(error)
            return
        }

        // Validate Google CDN URLs — if expired, trigger refresh in background (non-blocking)
        if containsGoogleCDNURLs(state.cachedURLs) && !googleCDNCheckedForPlace.contains(placeId) {
            googleCDNCheckedForPlace.insert(placeId)
            let isValid = await validateSampleGoogleCDNURL(from: state.cachedURLs)
            if !isValid && !refreshRequestedForPlace.contains(placeId) {
                let cachedURLs = state.cachedURLs
                Task { [weak self] in
                    await self?.triggerRefreshAndReload(for: placeId, expiredURLs: cachedURLs)
                }
            }
        }

        let candidateURLs = Array(state.cachedURLs.dropFirst(state.photoCursor).prefix(externalReviewPhotoBatchSize))
        let loadedURLs = loadedExternalPhotoURLs[placeId] ?? []
        let expiredURLs = failedImageURLs[placeId] ?? []
        let urlsToAdd = candidateURLs.filter { !loadedURLs.contains($0) && !expiredURLs.contains($0) }

        if await handleRetryIfNeeded(for: place, placeId: placeId, urlsToAdd: urlsToAdd, state: state) {
            return
        }

        applyPhotoBatch(urlsToAdd: urlsToAdd, candidateURLs: candidateURLs, placeId: placeId, state: &state)
        validateDisplayedGoogleCDNURLs(for: placeId)
    }

    /// Retries loading if no reviews were found and retry budget remains. Returns true if a retry was initiated.
    private func handleRetryIfNeeded(for place: DetailPlace, placeId: String, urlsToAdd: [String], state: PaginationState) async -> Bool {
        guard urlsToAdd.isEmpty && state.cachedURLs.isEmpty && !state.hasMoreReviews else { return false }

        let retryCount = self.externalReviewRetryAttempts[placeId] ?? 0
        guard retryCount < maxExternalReviewRetries else {
            print("⚠️ [ExternalReviewPhotosVM] No external reviews after \(maxExternalReviewRetries) retries for \(placeId)")
            return false
        }

        self.externalReviewRetryAttempts[placeId] = retryCount + 1
        try? await Task.sleep(nanoseconds: UInt64(externalReviewRetryDelay * 1_000_000_000))
        await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: false)
        return true
    }

    /// Applies a batch of photo URLs to the published state and updates pagination.
    private func applyPhotoBatch(urlsToAdd: [String], candidateURLs: [String], placeId: String, state: inout PaginationState) {
        if urlsToAdd.isEmpty {
            state.photoCursor += candidateURLs.count
            persistPaginationState(state, loadingState: .loaded)
        } else {
            let newItems = urlsToAdd.map { PhotoItem(url: $0, source: .externalReview) }
            let existingItems = self.externalReviewPhotoItems[placeId] ?? []
            self.externalReviewPhotoItems[placeId] = existingItems + newItems

            state.photoCursor += candidateURLs.count
            markURLsAsLoaded(urlsToAdd, for: placeId)
            self.externalReviewRetryAttempts[placeId] = 0
            persistPaginationState(state, loadingState: .loaded)
        }
    }

    /// Extends the URL cache by fetching more external review pages.
    private func extendURLCache(placeId: String, state: inout PaginationState) async throws {
        while state.cachedURLs.count < state.photoCursor + externalReviewPhotoBatchSize && state.hasMoreReviews {
            let page = try await postService.fetchExternalReviewMedia(
                placeId: placeId,
                reviewOffset: state.reviewOffset,
                reviewLimit: externalReviewReviewBatchSize
            )

            let newUniqueURLs = deduplicateURLs(page.urls, state: &state)
            state.cachedURLs.append(contentsOf: newUniqueURLs)
            state.reviewOffset = page.nextReviewOffset
            state.hasMoreReviews = page.hasMore
        }
    }

    /// Filters out already-seen URLs from a batch.
    private func deduplicateURLs(_ urls: [String], state: inout PaginationState) -> [String] {
        var uniqueURLs: [String] = []
        for url in urls {
            guard !state.seenURLs.contains(url) else { continue }
            state.seenURLs.insert(url)
            uniqueURLs.append(url)
        }
        return uniqueURLs
    }

    /// Marks URLs as loaded to prevent future duplicate loads.
    private func markURLsAsLoaded(_ urls: [String], for placeId: String) {
        if loadedExternalPhotoURLs[placeId] == nil {
            loadedExternalPhotoURLs[placeId] = []
        }
        loadedExternalPhotoURLs[placeId]?.formUnion(urls)
    }

    // MARK: - Per-Image Failure Recovery

    /// Collects individual image load failures and triggers a debounced refresh.
    func reportImageLoadFailure(url: String) {
        guard url.contains("lh3.googleusercontent.com") else { return }
        guard let placeId = place?.id.uuidString else { return }
        guard !perImageRefreshAttempted.contains(placeId) else { return }
        guard !(isRefreshingImagesByPlace[placeId] ?? false) else { return }

        if failedImageURLs[placeId] == nil {
            failedImageURLs[placeId] = []
        }
        failedImageURLs[placeId]?.insert(url)

        pendingFailureRefreshTask?.cancel()
        pendingFailureRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return
            }
            await self?.executePerImageRefresh(for: placeId)
        }
    }

    /// Validates all displayed Google CDN URLs via background HEAD requests and triggers refresh for expired ones.
    private func validateDisplayedGoogleCDNURLs(for placeId: String) {
        guard !backgroundValidationStarted.contains(placeId) else { return }
        guard !perImageRefreshAttempted.contains(placeId) else { return }

        let items = externalReviewPhotoItems[placeId] ?? []
        let googleURLs = items.map(\.url).filter { $0.contains("lh3.googleusercontent.com") }
        guard !googleURLs.isEmpty else { return }

        backgroundValidationStarted.insert(placeId)

        Task { [weak self] in
            let expired = await self?.findExpiredGoogleCDNURLs(googleURLs) ?? []
            guard !expired.isEmpty else { return }

            let expiredSet = Set(expired)
            self?.externalReviewPhotoItems[placeId]?.removeAll { expiredSet.contains($0.url) }

            print("📸 [ExternalReviewPhotosVM] Background validation found \(expired.count) expired URLs for \(placeId), removed from display")
            self?.failedImageURLs[placeId] = expiredSet
            await self?.executePerImageRefresh(for: placeId)
        }
    }

    /// Checks Google CDN URLs via parallel HEAD requests on the processed (high-res) URL and returns original URLs that return 403.
    private nonisolated func findExpiredGoogleCDNURLs(_ urls: [String]) async -> [String] {
        await withTaskGroup(of: (String, Bool).self, returning: [String].self) { group in
            for urlString in urls {
                group.addTask {
                    let processedURL = ImageLoadingUtility.getHighResGoogleURL(urlString, maxSize: 1600)
                    guard let url = URL(string: processedURL) else { return (urlString, true) }
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5

                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200
                        return (urlString, statusCode != 403)
                    } catch {
                        return (urlString, true)
                    }
                }
            }

            var expired: [String] = []
            for await (url, isValid) in group {
                if !isValid { expired.append(url) }
            }
            return expired
        }
    }

    /// Executes a batched refresh for all collected per-image failures.
    private func executePerImageRefresh(for placeId: String) async {
        guard let failedURLs = failedImageURLs[placeId], !failedURLs.isEmpty else { return }

        perImageRefreshAttempted.insert(placeId)
        googleCDNCheckedForPlace.remove(placeId)

        print("📸 [ExternalReviewPhotosVM] Per-image refresh for \(failedURLs.count) failed URLs in \(placeId)")
        await triggerRefreshAndReload(for: placeId, expiredURLs: Array(failedURLs))
    }

    // MARK: - Proactive Google CDN Validation

    /// Returns true if any URLs are Google CDN URLs that may expire.
    private func containsGoogleCDNURLs(_ urls: [String]) -> Bool {
        urls.contains { $0.contains("lh3.googleusercontent.com") }
    }

    /// Performs a HEAD request on the processed (high-res) version of a sample Google CDN URL to check if it has expired.
    private func validateSampleGoogleCDNURL(from urls: [String]) async -> Bool {
        guard let sampleURL = urls.first(where: { $0.contains("lh3.googleusercontent.com") }) else {
            return true
        }

        let processedSampleURL = ImageLoadingUtility.getHighResGoogleURL(sampleURL, maxSize: 1600)
        guard let url = URL(string: processedSampleURL) else { return true }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200
            if statusCode == 403 {
                print("📸 [ExternalReviewPhotosVM] Google CDN URL expired (403): \(sampleURL.prefix(80))...")
                return false
            }
            return true
        } catch {
            print("📸 [ExternalReviewPhotosVM] HEAD request failed (assuming valid): \(error.localizedDescription)")
            return true
        }
    }

    /// Triggers a backend refresh for expired Google CDN URLs, waits if processing, then reloads photos.
    private func triggerRefreshAndReload(for placeId: String, expiredURLs: [String]) async {
        guard !(isRefreshingImagesByPlace[placeId] ?? false) else { return }
        refreshRequestedForPlace.insert(placeId)
        isRefreshingImagesByPlace[placeId] = true

        do {
            let refreshInitiated = try await MesaBackendService.shared.requestImageRefresh(
                placeId: placeId,
                failedURLs: expiredURLs.filter { $0.contains("lh3.googleusercontent.com") }
            )

            if refreshInitiated {
                print("📸 [ExternalReviewPhotosVM] Backend refresh initiated for \(placeId), waiting for processing...")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                isRefreshingImagesByPlace[placeId] = false
                await retryAfterRefresh(for: placeId)
            } else {
                print("📸 [ExternalReviewPhotosVM] Backend refresh rate-limited for \(placeId), skipping retry")
                isRefreshingImagesByPlace[placeId] = false
            }
        } catch {
            print("📸 [ExternalReviewPhotosVM] Backend refresh failed for \(placeId): \(error)")
            isRefreshingImagesByPlace[placeId] = false
        }
    }

    /// Retries loading external photos after backend has refreshed the image URLs.
    private func retryAfterRefresh(for placeId: String) async {
        guard let place = place, place.id.uuidString == placeId else { return }

        print("📸 [ExternalReviewPhotosVM] Retrying after refresh for \(placeId)")

        externalReviewPhotoItems[placeId] = []
        externalReviewImageURLCache[placeId] = []
        externalReviewReviewOffsets[placeId] = 0
        externalReviewPhotoCursor[placeId] = 0
        externalReviewReviewHasMore[placeId] = true
        externalReviewPhotosAllLoadedByPlace[placeId] = false
        loadedExternalPhotoURLs[placeId]?.removeAll()
        externalSeenURLs[placeId]?.removeAll()

        await loadExternalReviewPhotosInternal(for: place, placeId: placeId, reset: false)
    }
}
