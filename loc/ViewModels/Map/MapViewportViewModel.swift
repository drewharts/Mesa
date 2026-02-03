//
//  MapViewportViewModel.swift
//  loc
//
//  Handles viewport loading, place caching, and place detail fetching.
//

import Foundation
import MapKit

@MainActor
class MapViewportViewModel: ObservableObject {
    @Published var viewportAnnotations: [PlaceAnnotation] = []
    @Published var communityMarkers: [CommunityPlaceMarker] = []
    @Published var isLoadingViewportPlaces: Bool = false

    private var debounceTimer: Timer?
    private var lastLoadedRegion: MKCoordinateRegion?
    private var placeDetailsCache: [String: DetailPlace] = [:]
    private var currentLoadTask: Task<Void, Never>?
    private let minMovementThreshold: Double = 0.01

    private let placeService: PlaceService
    private let mesaBackendService: MesaBackendService

    /// Callback invoked when annotations are loaded, allowing parent to trigger image generation.
    var onAnnotationsLoaded: (([PlaceAnnotation]) -> Void)?

    init(placeService: PlaceService, mesaBackendService: MesaBackendService = .shared) {
        self.placeService = placeService
        self.mesaBackendService = mesaBackendService
    }

    // MARK: - Viewport Loading

    /// Called when the map camera has settled to load places for the new viewport.
    func onMapCameraSettled(
        _ newRegion: MKCoordinateRegion,
        userId: String,
        filterState: MapFilterState
    ) async {
        if let lastRegion = lastLoadedRegion, !shouldReloadForRegion(newRegion, lastRegion: lastRegion) {
            return
        }

        await loadPlacesForViewport(newRegion, userId: userId, filterState: filterState)
    }

    /// Resets the last loaded region to force a reload on next camera settle.
    func resetLastLoadedRegion() {
        lastLoadedRegion = nil
    }

    /// Clears all annotations and markers.
    func clearAnnotations() {
        viewportAnnotations = []
        communityMarkers = []
    }

    // MARK: - Place Details

    /// Loads full place details on demand when user taps an annotation.
    /// Uses Mesa backend which checks Supabase cache first, then falls back to external APIs.
    func loadPlaceDetails(for annotation: PlaceAnnotation) async -> DetailPlace? {
        let placeId = annotation.id

        // Check local cache first (avoids network call entirely)
        if let cached = placeDetailsCache[placeId] {
            return cached
        }

        do {
            // Mesa backend checks Supabase cache first, then Serper if needed
            // This is more efficient than separate Supabase + backend calls
            let details = try await mesaBackendService.fetchPlaceDetails(placeId: placeId)
            placeDetailsCache[placeId] = details
            return details
        } catch {
            print("❌ [MapViewportViewModel] Error loading place details: \(error)")
            return nil
        }
    }

    /// Loads full place details for a community marker when user taps a white dot.
    /// Uses Mesa backend which checks Supabase cache first, then falls back to external APIs.
    func loadPlaceDetails(for marker: CommunityPlaceMarker) async -> DetailPlace? {
        let placeId = marker.id

        // Check local cache first
        if let cached = placeDetailsCache[placeId] {
            return cached
        }

        do {
            // Mesa backend checks Supabase cache first, then Serper if needed
            let details = try await mesaBackendService.fetchPlaceDetails(placeId: placeId)
            placeDetailsCache[placeId] = details
            return details
        } catch {
            print("❌ [MapViewportViewModel] Error loading community place details: \(error)")
            return nil
        }
    }

    // MARK: - Viewport Filtering

    /// Filters annotations for current viewport (client-side filtering).
    func getAnnotationsForViewport(_ region: MKCoordinateRegion) -> [PlaceAnnotation] {
        let bounds = getViewportBounds(from: region)

        return viewportAnnotations.filter { annotation in
            let lat = annotation.coordinate.latitude
            let lng = annotation.coordinate.longitude

            return lat >= bounds.southLat && lat <= bounds.northLat &&
                   lng >= bounds.westLng && lng <= bounds.eastLng
        }
    }

    /// Returns all place annotations to display on map.
    func getAllDisplayAnnotations() -> [PlaceAnnotation] {
        return viewportAnnotations
    }

    // MARK: - Private Methods

    /// Main method to load place annotations for a given viewport.
    private func loadPlacesForViewport(
        _ region: MKCoordinateRegion,
        userId: String,
        filterState: MapFilterState
    ) async {
        currentLoadTask?.cancel()

        let task = Task { @MainActor in
            guard !Task.isCancelled else { return }

            isLoadingViewportPlaces = true

            let bounds = getViewportBounds(from: region)

            do {
                guard !Task.isCancelled else {
                    isLoadingViewportPlaces = false
                    return
                }

                let annotations = try await fetchAnnotationsForFilter(
                    bounds: bounds,
                    userId: userId,
                    filterState: filterState
                )

                let community = try await fetchCommunityMarkers(
                    bounds: bounds,
                    userId: userId,
                    hasActiveFilter: filterState.hasActiveFilter
                )

                guard !Task.isCancelled else {
                    isLoadingViewportPlaces = false
                    return
                }

                self.viewportAnnotations = annotations

                // Filter out community markers that overlap with friends annotations
                let friendsPlaceIds = Set(annotations.map { $0.id })
                let filteredCommunity = community.filter { !friendsPlaceIds.contains($0.id) }

                let duplicateCount = community.count - filteredCommunity.count
                if duplicateCount > 0 {
                    let duplicateIds = community.filter { friendsPlaceIds.contains($0.id) }.map { $0.id }
                    print("🔍 [MapViewportViewModel] Filtered \(duplicateCount) duplicate community markers: \(duplicateIds)")
                }

                self.communityMarkers = filteredCommunity
                self.lastLoadedRegion = region

                // Notify parent to regenerate annotation images
                onAnnotationsLoaded?(annotations)

            } catch {
                let isCancelled = Task.isCancelled || error is CancellationError || (error as NSError).code == NSURLErrorCancelled
                if !isCancelled {
                    print("❌ [MapViewportViewModel] Error loading viewport annotations: \(error.localizedDescription)")
                }
            }

            isLoadingViewportPlaces = false
        }

        currentLoadTask = task
        await task.value
    }

    /// Fetches annotations based on the current filter state.
    private func fetchAnnotationsForFilter(
        bounds: ViewportBounds,
        userId: String,
        filterState: MapFilterState
    ) async throws -> [PlaceAnnotation] {
        if let extListId = filterState.externalListId, let extUserId = filterState.externalUserId {
            print("🗺️ [MapViewportViewModel] Fetching external list: listId=\(extListId), userId=\(extUserId)")
            return try await placeService.fetchListAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: extUserId,
                listId: extListId
            )
        } else if filterState.showingExternalReviewsOnMap, let extUserId = filterState.externalUserId {
            return try await placeService.fetchReviewAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: extUserId
            )
        } else if filterState.showingExternalFavoritesOnMap, let extUserId = filterState.externalUserId {
            return try await placeService.fetchFavoriteAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: extUserId
            )
        } else if let listId = filterState.selectedListId {
            return try await placeService.fetchListAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId,
                listId: listId
            )
        } else if filterState.showingTikToksOnMap {
            return try await placeService.fetchTikTokAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
        } else if filterState.showingReviewsOnMap {
            return try await placeService.fetchReviewAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
        } else if filterState.showingFavoritesOnMap {
            return try await placeService.fetchFavoriteAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
        } else if filterState.showingMyPlacesOnMap {
            return try await placeService.fetchMyPlacesAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
        } else if filterState.showingKeywordResultsPopup, let types = filterState.keywordTypesFilter {
            return try await placeService.fetchKeywordAnnotationsInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                types: types
            )
        } else {
            return try await placeService.fetchPlacesInViewportWithUserId(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
        }
    }

    /// Fetches community markers if no filter is active.
    private func fetchCommunityMarkers(
        bounds: ViewportBounds,
        userId: String,
        hasActiveFilter: Bool
    ) async throws -> [CommunityPlaceMarker] {
        guard !hasActiveFilter else { return [] }

        return try await placeService.fetchCommunityPlacesInViewportWithUserId(
            northLat: bounds.northLat,
            southLat: bounds.southLat,
            eastLng: bounds.eastLng,
            westLng: bounds.westLng,
            userId: userId
        )
    }

    /// Converts map region to lat/lng bounds.
    private func getViewportBounds(from region: MKCoordinateRegion) -> ViewportBounds {
        let centerLat = region.center.latitude
        let centerLng = region.center.longitude
        let latDelta = region.span.latitudeDelta
        let lngDelta = region.span.longitudeDelta

        return ViewportBounds(
            northLat: centerLat + (latDelta / 2),
            southLat: centerLat - (latDelta / 2),
            eastLng: centerLng + (lngDelta / 2),
            westLng: centerLng - (lngDelta / 2)
        )
    }

    /// Checks if region change is significant enough to reload.
    private func shouldReloadForRegion(_ newRegion: MKCoordinateRegion, lastRegion: MKCoordinateRegion) -> Bool {
        let latDiff = abs(newRegion.center.latitude - lastRegion.center.latitude)
        let lngDiff = abs(newRegion.center.longitude - lastRegion.center.longitude)

        let latMovementThreshold = lastRegion.span.latitudeDelta * 0.3
        let lngMovementThreshold = lastRegion.span.longitudeDelta * 0.3
        let centerMoved = latDiff > latMovementThreshold || lngDiff > lngMovementThreshold

        let latSpanChange = abs(newRegion.span.latitudeDelta - lastRegion.span.latitudeDelta)
        let lngSpanChange = abs(newRegion.span.longitudeDelta - lastRegion.span.longitudeDelta)
        let zoomChanged = latSpanChange > (lastRegion.span.latitudeDelta * 0.5) ||
                          lngSpanChange > (lastRegion.span.longitudeDelta * 0.5)

        return centerMoved || zoomChanged
    }

    deinit {
        debounceTimer?.invalidate()
    }
}

// MARK: - Supporting Types

/// Represents viewport bounds for database queries.
struct ViewportBounds {
    let northLat: Double
    let southLat: Double
    let eastLng: Double
    let westLng: Double
}

/// Represents the current filter state for map annotations.
struct MapFilterState {
    let selectedListId: String?
    let showingTikToksOnMap: Bool
    let showingReviewsOnMap: Bool
    let showingFavoritesOnMap: Bool
    let showingMyPlacesOnMap: Bool
    let showingKeywordResultsPopup: Bool
    let keywordTypesFilter: [String]?
    let externalUserId: String?
    let showingExternalReviewsOnMap: Bool
    let showingExternalFavoritesOnMap: Bool
    let externalListId: String?

    var hasActiveFilter: Bool {
        selectedListId != nil ||
        showingTikToksOnMap ||
        showingReviewsOnMap ||
        showingFavoritesOnMap ||
        showingMyPlacesOnMap ||
        showingKeywordResultsPopup ||
        externalUserId != nil
    }
}
