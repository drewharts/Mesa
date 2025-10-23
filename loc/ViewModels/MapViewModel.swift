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
    @Published var annotationImages: [String: UIImage] = [:] // Combined profile images for annotations
    @Published var userProfilePictures: [String: UIImage] = [:] // Cache of user profile pictures
    
    private var debounceTimer: Timer?
    private let placeService: PlaceService
    private let detailPlaceVM: DetailPlaceViewModel
    private var lastLoadedRegion: MKCoordinateRegion?
    private var placeDetailsCache: [String: DetailPlace] = [:] // Cache for full place details
    weak var profileViewModel: ProfileViewModel? // To access current user's profile
    
    // Minimum movement threshold to trigger reload (in degrees)
    private let minMovementThreshold: Double = 0.01 // ~1km at equator
    
    init(placeService: PlaceService, detailPlaceVM: DetailPlaceViewModel) {
        self.placeService = placeService
        self.detailPlaceVM = detailPlaceVM
    }
    
    /// Load profile photos for followed users (for custom annotation views)
    func loadFollowedUsersPhotos() async {
        // Use cached profile data instead of fetching again
        guard let currentUser = profileViewModel?.user else {
            print("⚠️ [MapViewModel] No user profile available for loading photos")
            return
        }
        
        let profileUserId = currentUser.id
        let currentUserPhotoUrl = currentUser.profilePhotoURL
        
        do {
            var photos = try await placeService.fetchFollowedUsersPhotos(userId: profileUserId)
            
            // Add current user's photo to the list (using cached data)
            if let photoUrl = currentUserPhotoUrl {
                let currentUserPhoto = FollowedUserPhoto(userId: profileUserId, profilePhotoUrl: photoUrl.absoluteString)
                photos.append(currentUserPhoto)
                print("📸 [MapViewModel] Added current user's photo to annotation list (from cache)")
            }
            
            self.followedUsersPhotos = photos
            print("📸 [MapViewModel] Loaded \(photos.count) total photos for annotations (including current user)")
            
            // Load profile pictures from URLs
            await loadProfilePictures(from: photos)
            
            // Generate annotation images for current annotations
            generateAnnotationImages()
            
        } catch {
            print("❌ [MapViewModel] Error loading followed users' photos: \(error)")
        }
    }
    
    /// Load profile pictures from URLs
    private func loadProfilePictures(from photos: [FollowedUserPhoto]) async {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for photo in photos {
                guard let urlString = photo.profilePhotoUrl,
                      let url = URL(string: urlString) else { continue }
                
                group.addTask {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return (photo.userId, UIImage(data: data))
                    } catch {
                        print("⚠️ Failed to load image for user \(photo.userId)")
                        return (photo.userId, nil)
                    }
                }
            }
            
            for await (userId, image) in group {
                if let image = image {
                    self.userProfilePictures[userId] = image
                }
            }
        }
    }
    
    /// Generate combined annotation images for all annotations
    func generateAnnotationImages() {
        for annotation in viewportAnnotations {
            // Get up to 3 profile pictures for users who saved this place
            let profilePictures = annotation.userIds.prefix(3).compactMap { userProfilePictures[$0] }
            
            // Create combined image
            let combinedImage: UIImage
            switch profilePictures.count {
            case 1:
                combinedImage = combinedCircularImage(image1: profilePictures[0])
            case 2:
                combinedImage = combinedCircularImage(image1: profilePictures[0], image2: profilePictures[1])
            case 3:
                combinedImage = combinedCircularImage(image1: profilePictures[0], image2: profilePictures[1], image3: profilePictures[2])
            default:
                // If no profile pictures, use a default image
                combinedImage = combinedCircularImage(image1: nil)
            }
            
            annotationImages[annotation.id] = combinedImage
        }
        print("✅ [MapViewModel] Generated \(annotationImages.count) annotation images")
    }
    
    /// Create combined circular image from profile pictures (matching existing implementation)
    private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
        let totalSize = CGSize(width: 80, height: 40)
        let singleCircleSize = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: totalSize)
       
        return renderer.image { context in
            let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let secondRect = CGRect(x: 15, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let thirdRect = CGRect(x: 30, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
           
            func drawCircularImage(_ image: UIImage?, in rect: CGRect) {
                guard let image = image else { return }
                context.cgContext.saveGState()
                let circlePath = UIBezierPath(ovalIn: rect)
                circlePath.addClip()
                image.draw(in: rect)
                context.cgContext.setStrokeColor(UIColor.white.cgColor)
                context.cgContext.setLineWidth(1.0)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
                context.cgContext.restoreGState()
            }
           
            if image3 != nil { drawCircularImage(image3, in: thirdRect) }
            if image2 != nil { drawCircularImage(image2, in: secondRect) }
            if image1 != nil { drawCircularImage(image1, in: firstRect) }
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
            
            // Generate annotation images for new annotations
            generateAnnotationImages()
            
            let loadTime = Date().timeIntervalSince(startTime)
            print("⏱️ [MapViewModel] Loaded \(annotations.count) place annotations in \(String(format: "%.2f", loadTime))s")
            
            
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

