//
//  MapViewModel.swift
//  loc
//
//  Created by Assistant on viewport-based loading implementation
//

import Foundation
import MapKit
import FirebaseFirestore

@MainActor
class MapViewModel: ObservableObject {
    @Published var viewportPlaces: [String: DetailPlace] = [:] // Places in current viewport
    @Published var isLoadingViewportPlaces: Bool = false
    
    private var debounceTimer: Timer?
    private let placeService: PlaceService
    private let detailPlaceVM: DetailPlaceViewModel
    private var lastLoadedRegion: MKCoordinateRegion?
    private var friendUserIds: [String] = []  // Store friend IDs for viewport queries
    
    // Minimum movement threshold to trigger reload (in degrees)
    private let minMovementThreshold: Double = 0.01 // ~1km at equator
    
    init(placeService: PlaceService, detailPlaceVM: DetailPlaceViewModel) {
        self.placeService = placeService
        self.detailPlaceVM = detailPlaceVM
    }
    
    /// Update friend IDs when they change (call this from ProfileViewModel)
    func updateFriendIds(_ friendIds: [String]) {
        self.friendUserIds = friendIds
        print("👥 [MapViewModel] Updated friend IDs count: \(friendIds.count)")
    }
    
    /// Call this when the map region changes (pan or zoom)
    func onMapRegionChange(_ newRegion: MKCoordinateRegion) {
        // Check if the region change is significant enough to warrant a reload
        if let lastRegion = lastLoadedRegion, !shouldReloadForRegion(newRegion, lastRegion: lastRegion) {
            return
        }
        
        // Debounce to avoid excessive queries while user is actively panning
        debounceTimer?.invalidate()
        
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,  // Wait 500ms after user stops moving
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadPlacesForViewport(newRegion)
            }
        }
    }
    
    /// Load places in the initial viewport (on app startup)
    func loadInitialViewportPlaces(_ region: MKCoordinateRegion) async {
        await loadPlacesForViewport(region)
    }
    
    /// Main method to load places for a given viewport
    /// Loads BOTH regular places AND friends' places in parallel (10x faster!)
    private func loadPlacesForViewport(_ region: MKCoordinateRegion) async {
        let startTime = Date()
        isLoadingViewportPlaces = true
        
        let bounds = getViewportBounds(from: region)
        
        do {
            // Load both regular places AND friends' places in parallel
            async let regularPlaces = placeService.fetchPlacesInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng
            )
            
            async let friendsPlaces = placeService.fetchFriendsPlacesInViewport(
                friendUserIds: friendUserIds,
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng
            )
            
            // Wait for both queries to complete
            let (regular, friends) = try await (regularPlaces, friendsPlaces)
            
            // Merge and deduplicate places
            var newViewportPlaces: [String: DetailPlace] = [:]
            for place in (regular + friends) {
                let placeId = place.id.uuidString
                newViewportPlaces[placeId] = place
                
                // Also update the main detailPlaceVM cache if not already present
                if detailPlaceVM.places[placeId] == nil {
                    detailPlaceVM.places[placeId] = place
                    detailPlaceVM.generateColorForPlace(placeId)
                    detailPlaceVM.calculateRestaurantType(for: place)
                }
            }
            
            self.viewportPlaces = newViewportPlaces
            self.lastLoadedRegion = region
            
            let loadTime = Date().timeIntervalSince(startTime)
            print("⏱️ [MapViewModel] Loaded \(regular.count) regular + \(friends.count) friends' places in \(String(format: "%.2f", loadTime))s")
            print("📊 [MapViewModel] Total viewport places: \(newViewportPlaces.count)")
            
        } catch {
            print("❌ [MapViewModel] Error loading viewport places: \(error.localizedDescription)")
        }
        
        isLoadingViewportPlaces = false
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
    
    /// Check if region change is significant enough to reload
    private func shouldReloadForRegion(_ newRegion: MKCoordinateRegion, lastRegion: MKCoordinateRegion) -> Bool {
        // Calculate center movement
        let latDiff = abs(newRegion.center.latitude - lastRegion.center.latitude)
        let lngDiff = abs(newRegion.center.longitude - lastRegion.center.longitude)
        let centerMoved = latDiff > minMovementThreshold || lngDiff > minMovementThreshold
        
        // Calculate zoom change (span change)
        let latSpanChange = abs(newRegion.span.latitudeDelta - lastRegion.span.latitudeDelta)
        let lngSpanChange = abs(newRegion.span.longitudeDelta - lastRegion.span.longitudeDelta)
        let zoomChanged = latSpanChange > (lastRegion.span.latitudeDelta * 0.3) || 
                          lngSpanChange > (lastRegion.span.longitudeDelta * 0.3)
        
        return centerMoved || zoomChanged
    }
    
    /// Get all places to display on map (viewport + user's saved places)
    func getAllDisplayPlaces() -> [DetailPlace] {
        // Combine viewport places with user's saved places
        var allPlaces = viewportPlaces
        
        // Merge in saved places from detailPlaceVM
        for (placeId, place) in detailPlaceVM.places {
            if allPlaces[placeId] == nil {
                // Only add if it's a user's saved place
                if detailPlaceVM.placeSavers[placeId] != nil {
                    allPlaces[placeId] = place
                }
            }
        }
        
        return Array(allPlaces.values)
    }
    
    deinit {
        debounceTimer?.invalidate()
    }
}

