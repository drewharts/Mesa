//
//  VisiblePlacesPopupViewModel.swift
//  loc
//
//  Smart ViewModel for the "Places in View" popup.
//  Single Responsibility: Manage visible places state, filtering, and coordinate data loading.
//
//  Dependencies: Services only (not other ViewModels)
//  - PlaceService for fetching place details and all places in viewport
//  - ImageCacheService for cached parallel image loading
//

import Foundation
import MapKit
import UIKit

@MainActor
class VisiblePlacesPopupViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var selectedFilter: VisiblePlacesFilter = .friends
    @Published var isLoadingImages: Bool = false
    @Published var isLoadingPlaces: Bool = false
    @Published private(set) var loadedImageCount: Int = 0
    @Published private(set) var placeImages: [String: UIImage] = [:]
    
    // MARK: - Data Sources (fetched directly from services)
    
    private(set) var friendsAnnotations: [PlaceAnnotation] = []
    private(set) var communityMarkers: [CommunityPlaceMarker] = []
    private var mapRegion: MKCoordinateRegion?
    
    // MARK: - Dependencies (Services only - SRP)
    
    private let placeService: PlaceService
    private let imageCache: ImageCacheService
    
    // MARK: - Constants
    
    private let imageBatchSize = 12  // Increased from 6 for better throughput
    
    // MARK: - Initialization
    
    init(
        placeService: PlaceService = PlaceService.shared,
        imageCache: ImageCacheService = ImageCacheService.shared
    ) {
        self.placeService = placeService
        self.imageCache = imageCache
    }
    
    // MARK: - Configuration (called by parent View)
    
    /// Configure the ViewModel with map region and existing images
    /// Fetches all places directly from services (no density filtering)
    func configure(
        mapRegion: MKCoordinateRegion?,
        userId: String?,
        existingPlaceImages: [String: UIImage]
    ) {
        self.mapRegion = mapRegion
        self.placeImages = existingPlaceImages
        
        guard let region = mapRegion, let userId = userId else {
            print("⚠️ [VisiblePlacesPopupVM] Cannot fetch places: missing region or userId")
            return
        }
        
        Task {
            await fetchAllPlacesInViewport(region: region, userId: userId)
        }
    }
    
    // MARK: - Computed Properties
    
    /// All visible places based on the current filter
    var visiblePlaces: [VisiblePlaceItem] {
        switch selectedFilter {
        case .friends:
            return friendsPlaces
        case .community:
            return communityPlaces
        }
    }
    
    /// Friends (network) places in the current viewport
    var friendsPlaces: [VisiblePlaceItem] {
        let filtered = filterToViewport(friendsAnnotations)
        return filtered.map { VisiblePlaceItem(annotation: $0) }
    }
    
    /// Community places in the current viewport
    var communityPlaces: [VisiblePlaceItem] {
        let filtered = filterCommunityToViewport(communityMarkers)
        return filtered.map { VisiblePlaceItem(marker: $0) }
    }
    
    
    // MARK: - Public Methods
    
    /// Check if a place has an image loaded
    func hasImage(for placeId: String) -> Bool {
        placeImages[placeId] != nil
    }
    
    /// Get cached image for a place
    func getImage(for placeId: String) -> UIImage? {
        placeImages[placeId]
    }
    
    /// Called when view appears - loads first batch of images
    func onAppear() {
        loadNextImageBatch()
    }
    
    /// Called when a cell appears - triggers loading if needed
    func onCellAppear(index: Int) {
        if index >= loadedImageCount - 3 && !isLoadingImages {
            loadNextImageBatch()
        }
    }
    
    /// Reset image loading state (called when filter changes)
    func resetImageLoading() {
        loadedImageCount = 0
        loadNextImageBatch()
    }
    
    /// Load full place details for navigation
    func loadPlaceDetails(for item: VisiblePlaceItem) async throws -> DetailPlace {
        return try await placeService.fetchPlace(withId: item.id)
    }
    
    // MARK: - Data Fetching (Private)
    
    /// Fetches all places in viewport without density filtering
    /// Uses separate SQL functions for friends and community places
    private func fetchAllPlacesInViewport(region: MKCoordinateRegion, userId: String) async {
        guard !isLoadingPlaces else { return }
        
        isLoadingPlaces = true
        defer { isLoadingPlaces = false }
        
        let bounds = getViewportBounds(from: region)
        
        do {
            let (friends, community) = try await fetchPlacesInParallel(
                bounds: bounds,
                userId: userId
            )
            
            self.friendsAnnotations = friends
            self.communityMarkers = community
            
            loadNextImageBatch()
        } catch {
            print("❌ [VisiblePlacesPopupVM] Error fetching all places in viewport: \(error)")
        }
    }
    
    /// Fetches friends and community places in parallel
    private func fetchPlacesInParallel(
        bounds: (northLat: Double, southLat: Double, eastLng: Double, westLng: Double),
        userId: String
    ) async throws -> ([PlaceAnnotation], [CommunityPlaceMarker]) {
        async let friendsTask = placeService.fetchAllFriendsPlacesInViewportWithUserId(
            northLat: bounds.northLat,
            southLat: bounds.southLat,
            eastLng: bounds.eastLng,
            westLng: bounds.westLng,
            userId: userId
        )
        
        async let communityTask = placeService.fetchAllCommunityPlacesInViewportWithUserId(
            northLat: bounds.northLat,
            southLat: bounds.southLat,
            eastLng: bounds.eastLng,
            westLng: bounds.westLng,
            userId: userId
        )
        
        return try await (friendsTask, communityTask)
    }
    
    /// Convert map region to lat/lng bounds
    private func getViewportBounds(from region: MKCoordinateRegion) -> (
        northLat: Double,
        southLat: Double,
        eastLng: Double,
        westLng: Double
    ) {
        let centerLat = region.center.latitude
        let centerLng = region.center.longitude
        let latDelta = region.span.latitudeDelta
        let lngDelta = region.span.longitudeDelta
        
        return (
            northLat: centerLat + (latDelta / 2),
            southLat: centerLat - (latDelta / 2),
            eastLng: centerLng + (lngDelta / 2),
            westLng: centerLng - (lngDelta / 2)
        )
    }
    
    // MARK: - Viewport Filtering (Private)
    
    private func filterToViewport(_ annotations: [PlaceAnnotation]) -> [PlaceAnnotation] {
        guard let region = mapRegion else { return annotations }
        
        return annotations.filter { annotation in
            isCoordinateInRegion(annotation.coordinate, region: region)
        }
    }
    
    private func filterCommunityToViewport(_ markers: [CommunityPlaceMarker]) -> [CommunityPlaceMarker] {
        guard let region = mapRegion else { return markers }
        
        return markers.filter { marker in
            isCoordinateInRegion(marker.coordinate, region: region)
        }
    }
    
    private func isCoordinateInRegion(_ coordinate: CLLocationCoordinate2D, region: MKCoordinateRegion) -> Bool {
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2
        
        return coordinate.latitude >= latMin && coordinate.latitude <= latMax &&
               coordinate.longitude >= lonMin && coordinate.longitude <= lonMax
    }
    
    // MARK: - Image Loading (Private)
    
    private func loadNextImageBatch() {
        guard !isLoadingImages else { return }
        
        let places = visiblePlaces
        let startIndex = loadedImageCount
        let endIndex = min(startIndex + imageBatchSize, places.count)
        
        guard startIndex < endIndex else { return }
        
        let placesToLoad = Array(places[startIndex..<endIndex])
        let placeIds = placesToLoad.map { $0.id }
        
        isLoadingImages = true
        
        Task {
            await loadImages(for: placeIds)
            loadedImageCount = endIndex
            isLoadingImages = false
        }
    }
    
    private func loadImages(for placeIds: [String]) async {
        do {
            // Step 1: Get image URLs from PlaceService
            let imageUrlMap = try await SupabasePlaceService.shared.fetchPlaceImagesWithFallback(for: placeIds)
            
            // Step 2: Delegate parallel loading to ImageCacheService (SRP)
            // This is ~4-6x faster than sequential loading and uses memory/disk cache
            let urlStrings = Array(imageUrlMap.values)
            let loadedImages = await imageCache.loadImages(from: urlStrings)
            
            // Step 3: Map results back to place IDs
            for (placeId, urlString) in imageUrlMap {
                if let image = loadedImages[urlString] {
                    placeImages[placeId] = image
                }
            }
        } catch {
            print("❌ [VisiblePlacesPopupVM] Error fetching place images: \(error)")
        }
    }
}
