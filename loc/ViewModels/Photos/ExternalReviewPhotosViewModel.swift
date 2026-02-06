//
//  ExternalReviewPhotosViewModel.swift
//  loc
//
//  Manages external review photo loading, pagination, retry logic, and 403 tracking.
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
    private let externalReviewPhotoBatchSize = 5
    private let maxExternalReviewRetries = 3
    private let externalReviewRetryDelay: TimeInterval = 2.0

    // MARK: - Deduplication
    private var loadedExternalPhotoURLs: [String: Set<String>] = [:]
    private var externalSeenURLs: [String: Set<String>] = [:]

    // MARK: - 403 Error Tracking
    private var failedExternalURLs: [String: Set<String>] = [:]
    private var refreshRequestedForPlace: Set<String> = []

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

    /// Tracks a URL that returned 403 Forbidden (expired Google CDN URL).
    func trackFailed403URL(_ url: String) {
        guard let currentPlaceId = place?.id.uuidString else { return }

        if failedExternalURLs[currentPlaceId] == nil {
            failedExternalURLs[currentPlaceId] = []
        }
        failedExternalURLs[currentPlaceId]?.insert(url)

        print("📸 [ExternalReviewPhotosVM] Tracked 403 error for URL (place: \(currentPlaceId)): \(url.prefix(60))...")
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

        let candidateURLs = Array(state.cachedURLs.dropFirst(state.photoCursor).prefix(externalReviewPhotoBatchSize))
        let loadedURLs = loadedExternalPhotoURLs[placeId] ?? []
        let urlsToAdd = candidateURLs.filter { !loadedURLs.contains($0) }

        if await handleRetryIfNeeded(for: place, placeId: placeId, urlsToAdd: urlsToAdd, state: state) {
            return
        }

        applyPhotoBatch(urlsToAdd: urlsToAdd, candidateURLs: candidateURLs, placeId: placeId, state: &state)
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
            let newItems = urlsToAdd.map { PhotoItem(url: $0) }
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

    // MARK: - Image Refresh (403 Recovery)

    /// Requests the backend to refresh stale external review images if needed.
    func requestImageRefreshIfNeeded(for placeId: String) async {
        guard let failedURLs = failedExternalURLs[placeId], !failedURLs.isEmpty else { return }

        guard !refreshRequestedForPlace.contains(placeId) else {
            print("📸 [ExternalReviewPhotosVM] Already requested refresh for \(placeId) this session")
            return
        }

        refreshRequestedForPlace.insert(placeId)
        isRefreshingImagesByPlace[placeId] = true

        await executeImageRefresh(for: placeId, failedURLs: failedURLs)

        isRefreshingImagesByPlace[placeId] = false
    }

    /// Calls the backend to refresh expired image URLs and retries loading on success.
    private func executeImageRefresh(for placeId: String, failedURLs: Set<String>) async {
        do {
            let refreshInitiated = try await MesaBackendService.shared.requestImageRefresh(
                placeId: placeId,
                failedURLs: Array(failedURLs)
            )

            if refreshInitiated {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                failedExternalURLs[placeId]?.removeAll()
                await retryAfterRefresh(for: placeId)
            }
        } catch {
            print("📸 [ExternalReviewPhotosVM] Failed to request image refresh: \(error)")
        }
    }

    /// Retries loading external photos after backend has refreshed the image URLs.
    private func retryAfterRefresh(for placeId: String) async {
        guard let place = place, place.id.uuidString == placeId else { return }

        print("📸 [ExternalReviewPhotosVM] Retrying after refresh for \(placeId)")

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
