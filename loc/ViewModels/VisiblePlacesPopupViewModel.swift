//
//  VisiblePlacesPopupViewModel.swift
//  loc
//
//  Smart ViewModel for the "Places in View" popup.
//  Single Responsibility: Manage visible places state, filtering, and coordinate data loading.
//
//  Loading strategy:
//  - Seeds instantly from the map's in-memory annotations so the grid renders on open
//  - Fetches the complete (non-density-filtered) friends and community sets independently
//  - Loads thumbnails per chunk of cells, publishing each image as soon as it arrives
//
//  Dependencies: Services only (not other ViewModels)
//  - PlaceService for fetching all places in viewport
//  - SupabasePlaceService for resolving place image URLs
//  - ImageCacheService for cached, downsampled image loading
//

import Foundation
import MapKit
import UIKit

@MainActor
class VisiblePlacesPopupViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedFilter: VisiblePlacesFilter = .friends {
        didSet { rebuildVisiblePlaces() }
    }
    @Published private(set) var visiblePlaces: [VisiblePlaceItem] = []
    @Published private(set) var isLoadingPlaces: Bool = false
    @Published private(set) var placeImages: [String: UIImage] = [:]
    /// place id -> resolved photo URL, used by the shared photo tiles.
    @Published private(set) var imageUrls: [String: String] = [:]

    /// Visible places as the shared tile model (photo URL when resolved, else colored placeholder).
    var tilePlaces: [LightweightPlace] {
        visiblePlaces.map { item in
            LightweightPlace(
                place_id: item.id,
                name: item.name,
                latitude: item.coordinate.latitude,
                longitude: item.coordinate.longitude,
                latest_review_photo: nil,
                place_type: item.placeType,
                thumbnail_url: imageUrls[item.id]
            )
        }
    }

    /// Index of a place in the visible list (for chunked photo loading).
    func index(of placeId: String) -> Int? {
        visiblePlaces.firstIndex { $0.id == placeId }
    }

    // MARK: - Data Sources

    private var friendsAnnotations: [PlaceAnnotation] = [] {
        didSet { rebuildVisiblePlaces() }
    }
    private var communityMarkers: [CommunityPlaceMarker] = [] {
        didSet { rebuildVisiblePlaces() }
    }
    private var viewportBounds: ViewportBounds?
    private var hasConfigured = false
    private var requestedImageIds = Set<String>()

    // MARK: - Dependencies (Services only - SRP)

    private let placeService: PlaceService
    private let placeImageService: SupabasePlaceService
    private let imageCache: ImageCacheService

    // MARK: - Constants

    private let imageChunkSize = 12
    private let imagePrefetchDistance = 6
    private static let thumbnailSize = CGSize(width: 200, height: 200)

    // MARK: - Initialization

    /// Creates the view model with its service dependencies.
    init(
        placeService: PlaceService = PlaceService.shared,
        placeImageService: SupabasePlaceService = SupabasePlaceService.shared,
        imageCache: ImageCacheService = ImageCacheService.shared
    ) {
        self.placeService = placeService
        self.placeImageService = placeImageService
        self.imageCache = imageCache
    }

    // MARK: - Configuration (called by parent View)

    /// Seeds the grid from the map's in-memory places, then fetches the complete viewport sets once.
    func configure(
        mapRegion: MKCoordinateRegion?,
        userId: String?,
        seedAnnotations: [PlaceAnnotation],
        seedCommunityMarkers: [CommunityPlaceMarker],
        existingPlaceImages: [String: UIImage]
    ) {
        guard !hasConfigured else { return }
        hasConfigured = true

        viewportBounds = mapRegion.map(ViewportBounds.init(region:))
        placeImages = existingPlaceImages
        friendsAnnotations = seedAnnotations
        communityMarkers = seedCommunityMarkers

        guard let bounds = viewportBounds, let userId else {
            print("⚠️ [VisiblePlacesPopupVM] Cannot fetch places: missing region or userId")
            return
        }

        Task { await fetchAllPlacesInViewport(bounds: bounds, userId: userId) }
    }

    // MARK: - Computed Properties

    /// Returns true when places are still loading and there is nothing to show yet.
    var showsLoadingIndicator: Bool {
        isLoadingPlaces && visiblePlaces.isEmpty
    }

    // MARK: - Public Methods

    /// Returns the cached thumbnail for a place, if loaded.
    func getImage(for placeId: String) -> UIImage? {
        placeImages[placeId]
    }

    /// Requests thumbnails for the chunk containing this cell and prefetches the next chunk when close to it.
    func onCellAppear(index: Int) {
        requestImages(forChunkContaining: index)
        requestImages(forChunkContaining: index + imagePrefetchDistance)
    }

    // MARK: - Visible Places

    /// Recomputes the filtered, viewport-bounded place list and starts loading the first chunk of thumbnails.
    private func rebuildVisiblePlaces() {
        visiblePlaces = makeVisiblePlaces(filter: selectedFilter, friends: friendsAnnotations, community: communityMarkers)
        requestImages(forChunkContaining: 0)
    }

    /// Builds display items for the selected filter, limited to places inside the map region.
    private func makeVisiblePlaces(
        filter: VisiblePlacesFilter,
        friends: [PlaceAnnotation],
        community: [CommunityPlaceMarker]
    ) -> [VisiblePlaceItem] {
        switch filter {
        case .friends:
            return friends.filter { isInRegion($0.coordinate) }.map(VisiblePlaceItem.init(annotation:))
        case .community:
            return community.filter { isInRegion($0.coordinate) }.map(VisiblePlaceItem.init(marker:))
        }
    }

    /// Returns whether a coordinate falls within the viewport (always true when no region was provided).
    private func isInRegion(_ coordinate: CLLocationCoordinate2D) -> Bool {
        viewportBounds?.contains(coordinate) ?? true
    }

    // MARK: - Data Fetching (Private)

    /// Fetches friends and community places independently so each tab fills in as soon as its RPC returns.
    private func fetchAllPlacesInViewport(bounds: ViewportBounds, userId: String) async {
        isLoadingPlaces = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFriendsPlaces(bounds: bounds, userId: userId) }
            group.addTask { await self.loadCommunityPlaces(bounds: bounds, userId: userId) }
        }
        isLoadingPlaces = false
    }

    /// Replaces the seeded friends places with the complete set; keeps the seed on failure.
    private func loadFriendsPlaces(bounds: ViewportBounds, userId: String) async {
        do {
            friendsAnnotations = try await placeService.fetchAllFriendsPlacesInViewportWithUserId(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
        } catch {
            print("❌ [VisiblePlacesPopupVM] Error fetching friends places: \(error)")
        }
    }

    /// Replaces the seeded community places with the complete set; keeps the seed on failure.
    private func loadCommunityPlaces(bounds: ViewportBounds, userId: String) async {
        do {
            communityMarkers = try await placeService.fetchAllCommunityPlacesInViewportWithUserId(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng,
                userId: userId
            )
        } catch {
            print("❌ [VisiblePlacesPopupVM] Error fetching community places: \(error)")
        }
    }

    // MARK: - Image Loading (Private)

    /// Starts loading thumbnails for the not-yet-requested places in the chunk containing the given index.
    private func requestImages(forChunkContaining index: Int) {
        let chunkStart = (index / imageChunkSize) * imageChunkSize
        guard chunkStart < visiblePlaces.count else { return }
        let chunkEnd = min(chunkStart + imageChunkSize, visiblePlaces.count)

        let placeIds = visiblePlaces[chunkStart..<chunkEnd]
            .map(\.id)
            .filter { placeImages[$0] == nil && !requestedImageIds.contains($0) }
        guard !placeIds.isEmpty else { return }

        requestedImageIds.formUnion(placeIds)
        Task { await loadImages(for: placeIds) }
    }

    /// Resolves image URLs for the places, then downloads downsampled thumbnails and publishes each as it arrives.
    private func loadImages(for placeIds: [String]) async {
        let imageUrlMap: [String: String]
        do {
            imageUrlMap = try await placeImageService.fetchPlaceImagesWithFallback(for: placeIds)
        } catch {
            requestedImageIds.subtract(placeIds)
            print("❌ [VisiblePlacesPopupVM] Error fetching place image URLs: \(error)")
            return
        }
        imageUrls.merge(imageUrlMap) { _, new in new }

        let cache = imageCache
        let thumbnailSize = Self.thumbnailSize
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for (placeId, urlString) in imageUrlMap {
                guard let url = URL(string: urlString) else { continue }
                group.addTask { (placeId, await cache.fetchImage(for: url, targetSize: thumbnailSize)) }
            }
            for await (placeId, image) in group {
                if let image { placeImages[placeId] = image }
            }
        }
    }
}
