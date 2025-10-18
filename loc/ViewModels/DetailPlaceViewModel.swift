//
//  DetailPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/22/25.
//

import Foundation
import UIKit
import SwiftUI

@MainActor
class DetailPlaceViewModel: ObservableObject {
    @Published var places: [String: DetailPlace] = [:] // Formerly placeLookup
    @Published var placeImages: [String: UIImage] = [:] // Consolidated place images
    @Published var placeSavers: [String: [String]] = [:] // Tracks who saved each place PlaceId -> UserIds
    @Published var placeAnnotations: [String: UIImage] = [:] // Each place annotation's combined profile images
    @Published var placeTypes: [String: String] = [:] // Tracks restaurant types
    @Published var placeImageLoadingStates: [String: Bool] = [:] // Tracks if we've finished loading images for each place

    @Published var userProfilePicture: [String: UIImage] = [:] // Each user's profile picture

    @Published var placeColors: [String: Color] = [:] // Persistent color for each placeId

    private let placeService: PlaceService
    private let userService: UserService
    var dataManager: DataManager? // Reference to DataManager for lazy loading
    
    private var notificationObserver: NSObjectProtocol?
    private let placeDetailVM = PlaceDetailViewModel() // For restaurant type calculation

    init(placeService: PlaceService, userService: UserService) {
        self.placeService = placeService
        self.userService = userService
        // Add observer for map refresh notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshMapAnnotations"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("DetailPlaceViewModel received map refresh notification")
            // Force a refresh by triggering objectWillChange
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func removeUserFromPlaceSavers(userId: String) {
        for (placeId, savers) in placeSavers {
            placeSavers[placeId] = savers.filter { $0 != userId }
        }
    }
    
    func calculateAnnotationPlaces() {
        for (placeId, userIds) in placeSavers {
            // Get up to 3 profile pictures for this place's savers
            let profilePictures = userIds.prefix(3).compactMap { userProfilePicture[$0] }
            
            // Create combined image using the existing function
            let combinedImage: UIImage
            switch profilePictures.count {
            case 1:
                combinedImage = combinedCircularImage(image1: profilePictures[0])
            case 2:
                combinedImage = combinedCircularImage(image1: profilePictures[0], image2: profilePictures[1])
            case 3:
                combinedImage = combinedCircularImage(image1: profilePictures[0], image2: profilePictures[1], image3: profilePictures[2])
            default:
                // If no profile pictures, use a default image or nil
                combinedImage = combinedCircularImage(image1: nil)
            }
            
            // Store the combined image in placeAnnotations
            DispatchQueue.main.async {
                self.placeAnnotations[placeId] = combinedImage
                self.objectWillChange.send()
            }
        }
    }
    
    deinit {
        // Remove observer when this view model is deallocated
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Calculate and store restaurant type
    func calculateRestaurantType(for place: DetailPlace) {
        // Ensure this runs on the main thread to avoid race conditions
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let placeId = place.id.uuidString
            
            // Check if we already have the type calculated
            if self.placeTypes[placeId] != nil {
                return
            }
            
            // Safely get the restaurant type
            if let type = self.placeDetailVM.getRestaurantType(for: place) {
                self.placeTypes[placeId] = type
            } else {
                self.placeTypes[placeId] = PlaceTypes.defaultType
            }
        }
    }
    
    // Public method to calculate restaurant type synchronously (for on-demand filtering)
    func calculateRestaurantTypeSync(for place: DetailPlace) -> String {
        let placeId = place.id.uuidString
        
        // Check if we already have the type calculated
        if let existingType = placeTypes[placeId] {
            return existingType
        }
        
        // Calculate the type synchronously
        let type = placeDetailVM.getRestaurantType(for: place) ?? PlaceTypes.defaultType
        
        // Store it for future use
        DispatchQueue.main.async {
            self.placeTypes[placeId] = type
        }
        
        return type
    }

    // Fetch place data (e.g., from Firestore)
    func fetchPlaceDetails(placeId: String, completion: @escaping (DetailPlace?) -> Void) {
        placeService.fetchPlace(withId: placeId) { [weak self] result in
            guard let self = self else {
                completion(nil)
                return
            }
            switch result {
            case .success(let detailPlace):
                DispatchQueue.main.async {
                    self.places[placeId] = detailPlace
                    self.fetchPlaceImage(for: placeId) // Fetch image if not already present
                    self.calculateRestaurantType(for: detailPlace) // Calculate restaurant type
                    self.generateColorForPlace(placeId) // Generate color for fetched place
                    completion(detailPlace)
                }
            case .failure(let error):
                print("Error fetching place \(placeId): \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    func fetchPlaceImage(for placeId: String) {
        guard placeImages[placeId] == nil else { return }
        
        // Set loading state to true when we start loading
        placeImageLoadingStates[placeId] = true
        
        // This method is for normal place tiles that get images from reviews OR place's own photoUrls
        // TikTok place tiles use AsyncImage directly with TikTok URLs
        
        // First, check if the place has its own photoUrls (for created places)
        if let place = places[placeId], 
           let photoUrls = place.photoUrls, 
           !photoUrls.isEmpty {
            print("📸 [DetailPlaceViewModel] Place \(placeId) has its own photoUrls, loading directly")
            ImageService.shared.fetchPhotosFromStorage(urls: photoUrls) { [weak self] images, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [DetailPlaceViewModel] Error loading place's own images for \(placeId): \(error.localizedDescription)")
                        self.placeImages[placeId] = UIImage()
                    } else if let images = images, !images.isEmpty {
                        print("✅ [DetailPlaceViewModel] Successfully loaded place's own image for \(placeId)")
                        self.placeImages[placeId] = images[0]
                    } else {
                        print("⚠️ [DetailPlaceViewModel] No images found in place's photoUrls for \(placeId)")
                        self.placeImages[placeId] = UIImage()
                    }
                    // Mark loading as complete
                    self.placeImageLoadingStates[placeId] = false
                }
            }
            return
        }
        
        // If no place photoUrls, try to get images from reviews (for reviewed places)
        // Get the current user ID
        Task { @MainActor in
            guard let currentUserId = await SupabaseAuthService.shared.currentUserId else {
                print("Error: Current user ID is not available")
                self.placeImages[placeId] = UIImage()
                self.placeImageLoadingStates[placeId] = false
                return
            }
            
            self.fetchPlaceImageWithUserId(placeId: placeId, currentUserId: currentUserId)
        }
    }
    
    private func fetchPlaceImageWithUserId(placeId: String, currentUserId: String) {
        
        // Fetch ALL reviews for this place (not just friends' reviews) to get images for tiles
        Task {
            do {
                let reviews = try await ReviewService.shared.fetchPlaceReviews(placeId: placeId, latestOnly: false)
                
                // Find reviews with images
                let reviewsWithImages = reviews.filter { !$0.images.isEmpty }
                
                // Get the most recent review with images
                guard let mostRecentReview = reviewsWithImages.first else {
                    print("⚠️ [DetailPlaceViewModel] No reviews with images found for place \(placeId)")
                    await MainActor.run {
                        self.tryTikTokThumbnailAsCover(placeId: placeId)
                    }
                    return
                }
                
                // Only get the first image from the most recent review (most efficient)
                guard let firstImageUrl = mostRecentReview.images.first else {
                    print("⚠️ [DetailPlaceViewModel] Most recent review has no images for place \(placeId)")
                    await MainActor.run {
                        self.tryTikTokThumbnailAsCover(placeId: placeId)
                    }
                    return
                }
                
                print("📸 [DetailPlaceViewModel] Loading first image from most recent review for place \(placeId)")
                
                // Load only the first image from the most recent review
                ImageService.shared.fetchPhotosFromStorage(urls: [firstImageUrl]) { [weak self] images, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ [DetailPlaceViewModel] Error fetching place image for \(placeId): \(error.localizedDescription)")
                            self.placeImages[placeId] = UIImage()
                        } else if let images = images, !images.isEmpty {
                            print("✅ [DetailPlaceViewModel] Successfully loaded image from most recent review for place \(placeId)")
                            self.placeImages[placeId] = images[0]
                        } else {
                            print("⚠️ [DetailPlaceViewModel] No images loaded for place \(placeId)")
                            self.placeImages[placeId] = UIImage()
                        }
                        // Mark loading as complete
                        self.placeImageLoadingStates[placeId] = false
                    }
                }
            } catch {
                print("❌ [DetailPlaceViewModel] Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                await MainActor.run {
                    self.tryTikTokThumbnailAsCover(placeId: placeId)
                }
            }
        }
    }
    
    private func tryTikTokThumbnailAsCover(placeId: String) {
        // Look for place in our cached places
        guard let place = places[placeId],
              let tikTokVideos = place.tikTokVideos,
              !tikTokVideos.isEmpty,
              let firstThumbnailURL = tikTokVideos.first?.thumbnailURL else {
            print("⚠️ [DetailPlaceViewModel] No TikTok thumbnail available for place \(placeId)")
            DispatchQueue.main.async {
                // Set a special "no image" marker instead of nil to prevent infinite loading
                self.placeImages[placeId] = UIImage()
                // Mark loading as complete
                self.placeImageLoadingStates[placeId] = false
            }
            return
        }
        
        fetchTikTokThumbnailAsImage(thumbnailURL: firstThumbnailURL, placeId: placeId)
    }
    
    private func fetchTikTokThumbnailAsImage(thumbnailURL: String, placeId: String) {
        guard let url = URL(string: thumbnailURL) else {
            print("❌ [DetailPlaceViewModel] Invalid TikTok thumbnail URL for place \(placeId): \(thumbnailURL)")
            DispatchQueue.main.async {
                self.placeImages[placeId] = UIImage()
                self.placeImageLoadingStates[placeId] = false
            }
            return
        }
        
        print("📸 [DetailPlaceViewModel] Fetching TikTok thumbnail for place \(placeId) from: \(thumbnailURL)")
        
        // Create a URLRequest with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // 10 second timeout
        request.cachePolicy = .returnCacheDataElseLoad
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [DetailPlaceViewModel] Error fetching TikTok thumbnail for \(placeId): \(error.localizedDescription)")
                    self.placeImages[placeId] = UIImage()
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200, let data = data, !data.isEmpty {
                        if let image = UIImage(data: data) {
                            print("✅ [DetailPlaceViewModel] Successfully loaded TikTok thumbnail for place \(placeId)")
                            self.placeImages[placeId] = image
                        } else {
                            print("❌ [DetailPlaceViewModel] Failed to create UIImage from data for place \(placeId)")
                            self.placeImages[placeId] = UIImage()
                        }
                    } else {
                        print("❌ [DetailPlaceViewModel] HTTP error \(httpResponse.statusCode) for place \(placeId)")
                        self.placeImages[placeId] = UIImage()
                    }
                } else {
                    print("❌ [DetailPlaceViewModel] No response data for place \(placeId)")
                    self.placeImages[placeId] = UIImage()
                }
                // Mark loading as complete
                self.placeImageLoadingStates[placeId] = false
            }
        }.resume()
    }

    // Update placeSavers when a user saves a place
    func updatePlaceSavers(placeId: String, user: User) {
        print("fix later")
//        if placeSavers[placeId] != nil {
//            if !placeSavers[placeId]!.contains(where: { $0.id == user.id }) {
//                placeSavers[placeId]!.append(user)
//            }
//        } else {
//            placeSavers[placeId] = [user]
//        }
    }

    // Removed MapboxSearch searchResultToDetailPlace method - now using Google Places API
    
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
    
    var savedDetailPlaces: [DetailPlace] {
        placeSavers.keys.compactMap { placeId in
            places[placeId]
        }
    }
    
    // Add filtered places property
    var filteredDetailPlaces: [DetailPlace] {
        savedDetailPlaces
    }

    // Refresh all places data asynchronously
    @MainActor
    func refreshPlaces(detailPlaces: [String]) async {
        do {
            // Update local cache
            for place in detailPlaces {
                if self.placeImages[place] == nil {
                    fetchPlaceImage(for: place)
                }
                // Calculate restaurant type if not already calculated
                if let detailPlace = self.places[place], self.placeTypes[place] == nil {
                    calculateRestaurantType(for: detailPlace)
                }
                // Generate color if not already generated
                generateColorForPlace(place)
            }
            
            // Notify UI that data has changed
            self.objectWillChange.send()
            print("Successfully refreshed \(detailPlaces.count) places")
        }
    }

    // Recalculate place types for all places
    func recalculateAllPlaceTypes() {
        for (_, place) in places {
            calculateRestaurantType(for: place)
        }
        objectWillChange.send()
    }

    // Method to generate and store a color for a place
    func generateColorForPlace(_ placeId: String) {
        guard placeColors[placeId] == nil else { return }
        
        let color = Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
        placeColors[placeId] = color
    }
    
    // Public method to get a color for a place (read-only, no side effects)
    func colorForPlace(placeId: String) -> Color {
        if let color = placeColors[placeId] {
            return color
        } else {
            // Return a default color if not found
            // This should rarely happen as colors should be pre-generated
            return Color.gray
        }
    }
    
    // Public method to check if a place is still loading images
    func isPlaceImageLoading(placeId: String) -> Bool {
        return placeImageLoadingStates[placeId] ?? false
    }
    
    // Initialize colors for all existing places
    func initializePlaceColors() {
        for placeId in places.keys {
            generateColorForPlace(placeId)
        }
    }
}

