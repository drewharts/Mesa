//
//  VisiblePlacesPopupViewModel.swift
//  loc
//
//  Smart ViewModel for the "Places in View" popup.
//  Single Responsibility: Manage visible places state, filtering, and coordinate data loading.
//
//  Dependencies: Services only (not other ViewModels)
//  - PlaceService for fetching place details
//  - Image loading coordination
//

import Foundation
import MapKit
import UIKit

@MainActor
class VisiblePlacesPopupViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var selectedFilter: VisiblePlacesFilter = .friends
    @Published var isLoadingImages: Bool = false
    @Published private(set) var loadedImageCount: Int = 0
    @Published private(set) var placeImages: [String: UIImage] = [:]
    
    // MARK: - Data Sources (set externally)
    
    private(set) var friendsAnnotations: [PlaceAnnotation] = []
    private(set) var communityMarkers: [CommunityPlaceMarker] = []
    private var mapRegion: MKCoordinateRegion?
    
    // MARK: - Dependencies (Services only - SRP)
    
    private let placeService: PlaceService
    
    // MARK: - Constants
    
    private let imageBatchSize = 6
    
    // MARK: - Initialization
    
    init(placeService: PlaceService = PlaceService.shared) {
        self.placeService = placeService
    }
    
    // MARK: - Configuration (called by parent View)
    
    /// Configure the ViewModel with data from parent's environment objects
    /// This keeps the ViewModel decoupled from other ViewModels (SRP)
    func configure(
        friendsAnnotations: [PlaceAnnotation],
        communityMarkers: [CommunityPlaceMarker],
        mapRegion: MKCoordinateRegion?,
        existingPlaceImages: [String: UIImage]
    ) {
        self.friendsAnnotations = friendsAnnotations
        self.communityMarkers = communityMarkers
        self.mapRegion = mapRegion
        self.placeImages = existingPlaceImages
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
            // Use fallback method to get images from reviews OR place thumbnails/photos
            let imageMap = try await SupabasePlaceService.shared.fetchPlaceImagesWithFallback(for: placeIds)
            
            for placeId in placeIds {
                if let imageUrl = imageMap[placeId] {
                    await loadImage(from: imageUrl, for: placeId)
                }
            }
        } catch {
            print("❌ [VisiblePlacesPopupVM] Error fetching place images: \(error)")
        }
    }
    
    private func loadImage(from urlString: String, for placeId: String) async {
        guard let url = URL(string: urlString) else { return }
        guard placeImages[placeId] == nil else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                placeImages[placeId] = image
            }
        } catch {
            print("❌ [VisiblePlacesPopupVM] Error loading image for \(placeId): \(error)")
        }
    }
}
