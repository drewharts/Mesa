//
//  MapViewModel.swift
//  loc
//
//  Created by Assistant on viewport-based loading implementation
//

import Foundation
import MapKit
import SwiftUI

// MARK: - Sheet Type Enum
/// Identifies which sheet is currently being presented on the map
/// Using an enum with Identifiable allows SwiftUI to use a single .sheet(item:) modifier
enum MapSheetType: Identifiable, Equatable {
    case list(String)  // listId
    case tiktoks
    case reviews

    var id: String {
        switch self {
        case .list(let listId): return "list-\(listId)"
        case .tiktoks: return "tiktoks"
        case .reviews: return "reviews"
        }
    }
}

@MainActor
class MapViewModel: ObservableObject {
    @Published var viewportAnnotations: [PlaceAnnotation] = [] // Place annotations in current viewport
    @Published var communityMarkers: [CommunityPlaceMarker] = [] // Community places (from users you don't follow)
    @Published var isLoadingViewportPlaces: Bool = false
    @Published var followedUsersPhotos: [FollowedUserPhoto] = [] // Profile photos for custom annotations
    @Published var annotationImages: [String: UIImage] = [:] // Combined profile images for annotations
    @Published var userProfilePictures: [String: UIImage] = [:] // Cache of user profile pictures
    
    // Map filtering state
    @Published var selectedListId: String? = nil // When set, only show annotations from this list
    @Published var activeSheet: MapSheetType? = nil // Single sheet control - prevents multiple sheet conflicts
    @Published var pendingPlaceNavigation: String? = nil // Place ID to navigate to when sheet is open
    @Published var showingTikToksOnMap: Bool = false // When set, only show TikTok annotations
    @Published var showingReviewsOnMap: Bool = false // When set, only show reviewed place annotations

    // Computed properties for backwards compatibility with existing code
    var showingListPopup: Bool { if case .list = activeSheet { return true } else { return false } }
    var showingTikToksPopup: Bool { activeSheet == .tiktoks }
    var showingReviewsPopup: Bool { activeSheet == .reviews }
    
    private var debounceTimer: Timer?
    private let placeService: PlaceService
    private let detailPlaceVM: DetailPlaceViewModel
    private var lastLoadedRegion: MKCoordinateRegion?
    private var placeDetailsCache: [String: DetailPlace] = [:] // Cache for full place details
    private var currentLoadTask: Task<Void, Never>? // Track current loading task for cancellation
    
    // Photo loading state (for de-duplication)
    private var isLoadingPhotos = false
    private(set) var hasLoadedPhotos = false // Exposed for View to check
    
    // Minimum movement threshold to trigger reload (in degrees)
    private let minMovementThreshold: Double = 0.01 // ~1km at equator
    
    init(placeService: PlaceService, detailPlaceVM: DetailPlaceViewModel) {
        self.placeService = placeService
        self.detailPlaceVM = detailPlaceVM
    }
    
    // MARK: - List Filtering
    
    /// Validates that a list exists and sets it as the selected list for filtering map annotations
    /// MVVM: Business logic - validates list exists before updating state
    func selectList(_ listId: String, availableLists: [LightweightPlaceList]) {
        // Only set list and show popup if list exists in available lists
        guard availableLists.contains(where: { $0.id == listId }) else {
            // List not found - don't show popup
            return
        }

        selectedListId = listId
        showingTikToksOnMap = false
        showingReviewsOnMap = false
        activeSheet = .list(listId)
        // Clear current annotations - they will be reloaded with list filter
        viewportAnnotations = []
        communityMarkers = []
        // Reset last loaded region to force reload
        lastLoadedRegion = nil
    }

    /// Clears the list filter and restores all annotations
    func clearListFilter() {
        selectedListId = nil
        activeSheet = nil
        // Clear current annotations - they will be reloaded without filter
        viewportAnnotations = []
        communityMarkers = []
    }

    /// Sets the map to show only TikTok places
    func selectTikToks() {
        showingTikToksOnMap = true
        showingReviewsOnMap = false
        selectedListId = nil
        activeSheet = .tiktoks
        // Clear current annotations - they will be reloaded with TikTok filter
        viewportAnnotations = []
        communityMarkers = []
        lastLoadedRegion = nil
    }

    /// Sets the map to show only reviewed places
    func selectReviews() {
        showingReviewsOnMap = true
        showingTikToksOnMap = false
        selectedListId = nil
        activeSheet = .reviews
        // Clear current annotations - they will be reloaded with reviews filter
        viewportAnnotations = []
        communityMarkers = []
        lastLoadedRegion = nil
    }

    /// Clears all special filters (list, TikToks, reviews)
    func clearAllFilters() {
        selectedListId = nil
        showingTikToksOnMap = false
        showingReviewsOnMap = false
        activeSheet = nil
        viewportAnnotations = []
        communityMarkers = []
        lastLoadedRegion = nil
    }

    // MARK: - Photo Loading (Called by View when profile is available)
    
    /// Load profile photos for followed users (for custom annotation views)
    /// Called by View when user profile becomes available - View coordinates, ViewModel executes
    /// - Parameters:
    ///   - userId: The current user's profile ID
    ///   - currentUserPhotoUrl: Optional URL for current user's profile photo
    func loadFollowedUsersPhotos(userId: String, currentUserPhotoUrl: URL?) async {
        // Prevent duplicate/concurrent loads
        guard !isLoadingPhotos else { return }
        
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }
        
        do {
            var photos = try await placeService.fetchFollowedUsersPhotos(userId: userId)
            
            // Add current user's photo to the list
            if let photoUrl = currentUserPhotoUrl {
                let currentUserPhoto = FollowedUserPhoto(userId: userId, profilePhotoUrl: photoUrl.absoluteString)
                photos.append(currentUserPhoto)
            }
            
            self.followedUsersPhotos = photos
            self.hasLoadedPhotos = true
            
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
    }
    
    /// Create combined circular image from profile pictures (matching existing implementation)
    private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
        let totalSize = CGSize(width: 60, height: 30)
        let singleCircleSize = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: totalSize)
       
        return renderer.image { context in
            let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let secondRect = CGRect(x: 11, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let thirdRect = CGRect(x: 22, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
           
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
    
    /// Load full place details for a community marker (when user taps a white dot)
    func loadPlaceDetails(for marker: CommunityPlaceMarker) async -> DetailPlace? {
        let placeId = marker.id
        
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
            print("❌ [MapViewModel] Error loading community place details: \(error)")
            return nil
        }
    }
    
    // MARK: - Viewport Loading (Called by View with userId)
    
    /// Call this when the map camera has settled (using native iOS 17+ callback)
    /// Apple handles debouncing automatically, so we don't need manual timers
    /// - Parameters:
    ///   - newRegion: The map region to load places for
    ///   - userId: The current user's profile ID (passed by View from ProfileViewModel)
    func onMapCameraSettled(_ newRegion: MKCoordinateRegion, userId: String) async {
        // Check if the region change is significant enough to warrant a reload
        if let lastRegion = lastLoadedRegion, !shouldReloadForRegion(newRegion, lastRegion: lastRegion) {
            return
        }
        
        // Load places for the new viewport
        await loadPlacesForViewport(newRegion, userId: userId)
    }
    
    /// Main method to load place annotations for a given viewport
    /// Uses the optimized PostgreSQL function for ultra-fast loading
    /// Implements task cancellation to avoid redundant loads
    /// - Parameters:
    ///   - region: The map region to load places for
    ///   - userId: The current user's profile ID
    private func loadPlacesForViewport(_ region: MKCoordinateRegion, userId: String) async {
        // Cancel any previous loading task
        currentLoadTask?.cancel()
        
        let task = Task { @MainActor in
            // Check if cancelled before starting
            guard !Task.isCancelled else {
                return
            }
            
            isLoadingViewportPlaces = true
            
            let bounds = getViewportBounds(from: region)
            
            do {
                // Check if cancelled before network call
                guard !Task.isCancelled else {
                    isLoadingViewportPlaces = false
                    return
                }
                
                // Fetch annotations based on current filter (list, TikToks, reviews, or all)
                let annotations: [PlaceAnnotation]
                if let listId = selectedListId {
                    // Fetch annotations for the selected list only
                    annotations = try await placeService.fetchListAnnotationsInViewport(
                        northLat: bounds.northLat,
                        southLat: bounds.southLat,
                        eastLng: bounds.eastLng,
                        westLng: bounds.westLng,
                        userId: userId,
                        listId: listId
                    )
                } else if showingTikToksOnMap {
                    // Fetch annotations for TikTok places only
                    annotations = try await placeService.fetchTikTokAnnotationsInViewport(
                        northLat: bounds.northLat,
                        southLat: bounds.southLat,
                        eastLng: bounds.eastLng,
                        westLng: bounds.westLng,
                        userId: userId
                    )
                } else if showingReviewsOnMap {
                    // Fetch annotations for reviewed places only
                    annotations = try await placeService.fetchReviewAnnotationsInViewport(
                        northLat: bounds.northLat,
                        southLat: bounds.southLat,
                        eastLng: bounds.eastLng,
                        westLng: bounds.westLng,
                        userId: userId
                    )
                } else {
                    // Fetch all annotations (normal behavior)
                    annotations = try await placeService.fetchPlacesInViewportWithUserId(
                    northLat: bounds.northLat,
                    southLat: bounds.southLat,
                    eastLng: bounds.eastLng,
                    westLng: bounds.westLng,
                    userId: userId
                )
                }

                // Only fetch community markers if no filter is active
                let community: [CommunityPlaceMarker]
                let hasActiveFilter = selectedListId != nil || showingTikToksOnMap || showingReviewsOnMap
                if !hasActiveFilter {
                    community = try await placeService.fetchCommunityPlacesInViewportWithUserId(
                    northLat: bounds.northLat,
                    southLat: bounds.southLat,
                    eastLng: bounds.eastLng,
                    westLng: bounds.westLng,
                    userId: userId
                )
                } else {
                    // No community markers when filtering
                    community = []
                }
                
                // Check if cancelled after network call
                guard !Task.isCancelled else {
                    isLoadingViewportPlaces = false
                    return
                }
                
                self.viewportAnnotations = annotations
                
                // Filter out community markers that overlap with friends annotations
                // This prevents duplicate markers on the map (O(n+m) with Set lookup)
                let friendsPlaceIds = Set(annotations.map { $0.id })
                let filteredCommunity = community.filter { !friendsPlaceIds.contains($0.id) }
                
                // Debug: Log any duplicates that were filtered
                let duplicateCount = community.count - filteredCommunity.count
                if duplicateCount > 0 {
                    let duplicateIds = community.filter { friendsPlaceIds.contains($0.id) }.map { $0.id }
                    print("🔍 [MapViewModel] Filtered \(duplicateCount) duplicate community markers: \(duplicateIds)")
                }
                print("🔍 [MapViewModel] Friends: \(annotations.count), Community before: \(community.count), after: \(filteredCommunity.count)")
                
                self.communityMarkers = filteredCommunity
                
                self.lastLoadedRegion = region
                
                // Generate annotation images for new annotations
                generateAnnotationImages()
                
            } catch {
                // Don't log cancellation errors - they're expected when user pans/zooms quickly
                let isCancelled = Task.isCancelled || error is CancellationError || (error as NSError).code == NSURLErrorCancelled
                if !isCancelled {
                    print("❌ [MapViewModel] Error loading viewport annotations: \(error.localizedDescription)")
                }
            }
            
            isLoadingViewportPlaces = false
        }
        
        currentLoadTask = task
        await task.value
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

