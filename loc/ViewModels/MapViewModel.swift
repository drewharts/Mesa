//
//  MapViewModel.swift
//  loc
//
//  Created by Assistant on viewport-based loading implementation
//

import Foundation
import MapKit
import SwiftUI

@MainActor
class MapViewModel: ObservableObject {
    @Published var viewportAnnotations: [PlaceAnnotation] = [] // Place annotations in current viewport
    @Published var isLoadingViewportPlaces: Bool = false
    @Published var followedUsersPhotos: [FollowedUserPhoto] = [] // Profile photos for custom annotations
    
    private var debounceTimer: Timer?
    private let placeService: PlaceService
    private let detailPlaceVM: DetailPlaceViewModel
    private var lastLoadedRegion: MKCoordinateRegion?
    private var placeDetailsCache: [String: DetailPlace] = [:] // Cache for full place details
    
    // Minimum movement threshold to trigger reload (in degrees)
    private let minMovementThreshold: Double = 0.01 // ~1km at equator
    
    init(placeService: PlaceService, detailPlaceVM: DetailPlaceViewModel) {
        self.placeService = placeService
        self.detailPlaceVM = detailPlaceVM
    }
    
    /// Load profile photos for followed users (for custom annotation views)
    func loadFollowedUsersPhotos() async {
        guard let userId = await SupabaseAuthService.shared.currentUserId else {
            print("⚠️ [MapViewModel] No userId available for loading followed users' photos")
            return
        }
        
        do {
            let photos = try await placeService.fetchFollowedUsersPhotos(userId: userId)
            self.followedUsersPhotos = photos
            print("📸 [MapViewModel] Loaded \(photos.count) followed users' photos")
        } catch {
            print("❌ [MapViewModel] Error loading followed users' photos: \(error)")
        }
    }
    
    /// Load full place details on demand (when user taps an annotation)
    func loadPlaceDetails(for annotation: PlaceAnnotation) async -> DetailPlace? {
        let placeId = annotation.id
        
        // Check cache first
        if let cached = placeDetailsCache[placeId] {
            return cached
        }
        
        // Load from database
        do {
            let details = try await placeService.fetchPlaceDetails(placeId: placeId)
            if let details = details {
                placeDetailsCache[placeId] = details
            }
            return details
        } catch {
            print("❌ [MapViewModel] Error loading place details: \(error)")
            return nil
        }
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
            withTimeInterval: 0.8,  // 800ms for smoother experience
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadPlacesForViewport(newRegion)
            }
        }
    }
    
    /// Main method to load place annotations for a given viewport
    /// Uses the optimized PostgreSQL function for ultra-fast loading
    private func loadPlacesForViewport(_ region: MKCoordinateRegion) async {
        let startTime = Date()
        isLoadingViewportPlaces = true
        
        let bounds = getViewportBounds(from: region)
        
        do {
            // Use the optimized PostgreSQL function
            let annotations = try await placeService.fetchPlacesInViewport(
                northLat: bounds.northLat,
                southLat: bounds.southLat,
                eastLng: bounds.eastLng,
                westLng: bounds.westLng
            )
            
            self.viewportAnnotations = annotations
            self.lastLoadedRegion = region
            
            let loadTime = Date().timeIntervalSince(startTime)
            print("⏱️ [MapViewModel] Loaded \(annotations.count) place annotations in \(String(format: "%.2f", loadTime))s")
            
            // Debug: Log the annotations that were loaded
            print("🔍 [MapViewModel] Viewport annotations loaded:")
            for annotation in annotations {
                print("   - \(annotation.name) (\(annotation.id)) - saved by \(annotation.userIds.count) users")
            }
            
        } catch {
            print("❌ [MapViewModel] Error loading viewport annotations: \(error.localizedDescription)")
        }
        
        isLoadingViewportPlaces = false
    }
    
    // loadAllPlaceAnnotations method removed - we now use viewport-based loading exclusively
    
    /// Filter annotations for current viewport (client-side filtering)
    func getAnnotationsForViewport(_ region: MKCoordinateRegion) -> [PlaceAnnotation] {
        let bounds = getViewportBounds(from: region)
        
        return viewportAnnotations.filter { annotation in
            let lat = annotation.coordinate.latitude
            let lng = annotation.coordinate.longitude
            
            return lat >= bounds.southLat && lat <= bounds.northLat &&
                   lng >= bounds.westLng && lng <= bounds.eastLng
        }
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
        // Calculate center movement (increased threshold for smoother UX)
        let latDiff = abs(newRegion.center.latitude - lastRegion.center.latitude)
        let lngDiff = abs(newRegion.center.longitude - lastRegion.center.longitude)
        
        // Only reload if moved at least 30% of the current viewport
        let latMovementThreshold = lastRegion.span.latitudeDelta * 0.3
        let lngMovementThreshold = lastRegion.span.longitudeDelta * 0.3
        let centerMoved = latDiff > latMovementThreshold || lngDiff > lngMovementThreshold
        
        // Calculate zoom change (span change) - more conservative threshold
        let latSpanChange = abs(newRegion.span.latitudeDelta - lastRegion.span.latitudeDelta)
        let lngSpanChange = abs(newRegion.span.longitudeDelta - lastRegion.span.longitudeDelta)
        let zoomChanged = latSpanChange > (lastRegion.span.latitudeDelta * 0.5) || 
                          lngSpanChange > (lastRegion.span.longitudeDelta * 0.5)
        
        return centerMoved || zoomChanged
    }
    
    /// Get all place annotations to display on map
    func getAllDisplayAnnotations() -> [PlaceAnnotation] {
        return viewportAnnotations
    }
    
    deinit {
        debounceTimer?.invalidate()
    }
}

