//  PhotoImportViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import PhotosUI
import CoreLocation
import ImageIO
import UIKit

@MainActor
class PhotoImportViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var selectedImages: [UIImage] = []
    @Published var detectedCoordinates: (latitude: Double, longitude: Double)?
    @Published var isProcessingPhoto: Bool = false
    @Published var nearbyPlaces: [NearbyPlaceFeature] = []
    @Published var isLoadingNearbyPlaces: Bool = false
    @Published var showPlaceSelection: Bool = false
    @Published var selectedPlace: NearbyPlaceFeature?
    @Published var showPostCreation: Bool = false
    @Published var noLocationDataError: Bool = false
    @Published var shouldNavigateToPlaceDetail: Bool = false
    @Published var createdPlaceForDetail: DetailPlace?
    @Published var searchRadiusUsed: Int = 50
    @Published var isSavingPlace: Bool = false
    @Published var isUserCreatedPlace: Bool = false
    @Published var isInPhotoImportFlow: Bool = false
    @Published var resolvedPlace: DetailPlace?
    @Published var isResolvingPlace: Bool = false

    private let nearbyPlacesService: NearbyPlacesService
    private let placeService: PlaceService
    private let userService: UserService
    private let mesaBackendService: MesaBackendService

    init(
        nearbyPlacesService: NearbyPlacesService = NearbyPlacesService(),
        placeService: PlaceService = PlaceService.shared,
        userService: UserService = UserService.shared,
        mesaBackendService: MesaBackendService = MesaBackendService()
    ) {
        self.nearbyPlacesService = nearbyPlacesService
        self.placeService = placeService
        self.userService = userService
        self.mesaBackendService = mesaBackendService
    }

    // Callback for when a place is successfully saved
    var onPlaceSaved: (() -> Void)?
    var onPlaceSavedWithDetail: ((DetailPlace) -> Void)?
    
    func processSelectedPhotos() async {
        isInPhotoImportFlow = true
        guard !selectedItems.isEmpty else { return }
        
        isProcessingPhoto = true
        selectedImages = []
        detectedCoordinates = nil
        noLocationDataError = false
        
        // Show place selection screen immediately while processing
        await MainActor.run {
            showPlaceSelection = true
        }
        
        do {
            var foundCoordinates = false
            
            // Load all images first
            for item in selectedItems {
                if let imageData = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: imageData) {
                    selectedImages.append(image)
                }
            }
            
            // Now check each photo for coordinates until we find one
            for (index, item) in selectedItems.enumerated() {
                if let imageData = try await item.loadTransferable(type: Data.self) {
                    if await extractCoordinatesFromPhoto(data: imageData, photoIndex: index + 1) {
                        foundCoordinates = true
                        break // Stop once we find coordinates
                    }
                }
            }
            
            // If no coordinates found in any photo, show error
            if !foundCoordinates {
                print("❌ No GPS coordinates found in any of the selected photos")
                await MainActor.run {
                    noLocationDataError = true
                    showPlaceSelection = false // Hide place selection on error
                    isInPhotoImportFlow = false
                }
            }
            
        } catch {
            print("Failed to load photos: \(error.localizedDescription)")
            await MainActor.run {
                showPlaceSelection = false
                isInPhotoImportFlow = false
            }
        }
        
        isProcessingPhoto = false
    }
    
    private func extractCoordinatesFromPhoto(data: Data, photoIndex: Int) async -> Bool {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return false
        }

        guard let gpsData = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return false
        }
        
        // Extract GPS coordinates
        if let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
           let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double,
           let latitudeRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String {
            
            let finalLatitude = (latitudeRef == "S") ? -latitude : latitude
            let finalLongitude = (longitudeRef == "W") ? -longitude : longitude
            
            detectedCoordinates = (latitude: finalLatitude, longitude: finalLongitude)

            // Fetch nearby places
            await fetchNearbyPlaces(latitude: finalLatitude, longitude: finalLongitude)
            return true
        } else {
            return false
        }
    }
    
    func fetchNearbyPlaces(latitude: Double, longitude: Double) async {
        isLoadingNearbyPlaces = true
        
        do {
            // First try with default radius (50m)
            var response = try await nearbyPlacesService.fetchNearbyPlaces(
                latitude: latitude,
                longitude: longitude,
                radiusMeters: 50
            )
            
            nearbyPlaces = response.features

            // If no places found, try with larger radius (250m)
            if nearbyPlaces.isEmpty {
                response = try await nearbyPlacesService.fetchNearbyPlaces(
                    latitude: latitude,
                    longitude: longitude,
                    radiusMeters: 250
                )
                
                nearbyPlaces = response.features

                // If still no places found, try with even larger radius (1000m)
                if nearbyPlaces.isEmpty {
                    response = try await nearbyPlacesService.fetchNearbyPlaces(
                        latitude: latitude,
                        longitude: longitude,
                        radiusMeters: 1000
                    )
                    
                    nearbyPlaces = response.features

                    searchRadiusUsed = 1000
                } else {
                    searchRadiusUsed = 250
                }
            } else {
                searchRadiusUsed = 50
            }
            
        } catch {
            print("❌ Failed to fetch nearby places: \(error)")
        }
        
        isLoadingNearbyPlaces = false
    }
    
    func selectPlace(_ place: NearbyPlaceFeature) async {
        selectedPlace = place
        isUserCreatedPlace = false  // Always Google Place in photo import flow

        // Always fetch from backend to get proper UUID
        guard let googlePlaceId = place.properties.placeId else {
            print("❌ No Google Place ID found")
            resolvedPlace = convertToDetailPlace(place)
            showPlaceSelection = false
            showPostCreation = true
            return
        }

        isResolvingPlace = true
        do {
            let detailPlace = try await fetchPlaceFromBackend(googlePlaceId: googlePlaceId)
            resolvedPlace = detailPlace
        } catch {
            print("❌ Failed to resolve place from backend: \(error)")
            // Fallback to client-side conversion if backend fails
            resolvedPlace = convertToDetailPlace(place)
        }
        isResolvingPlace = false

        showPlaceSelection = false
        showPostCreation = true
    }
    
    private func saveSelectedPlaceToDatabase(_ nearbyPlace: NearbyPlaceFeature) async {
        guard let currentUserId = SupabaseAuthService.shared.currentUserId else {
            print("❌ No authenticated user found")
            return
        }

        isSavingPlace = true

        do {
            let detailPlace: DetailPlace

            // For Google Places, fetch from backend (handles deduplication)
            if let googlePlaceId = nearbyPlace.properties.placeId,
               nearbyPlace.properties.source != "user_created" {
                detailPlace = try await fetchPlaceFromBackend(googlePlaceId: googlePlaceId)
            } else {
                // User-created places - convert locally (they're unique by definition)
                detailPlace = convertToDetailPlace(nearbyPlace)
            }

            // Save to main places collection
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                placeService.addToAllPlaces(place: detailPlace) { error in
                    if let error = error {
                        print("❌ Error saving place to main collection: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            // Only save to user's myPlaces collection if this is a user-created place
            if nearbyPlace.properties.source == "user_created" {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    placeService.addToMyPlaces(userId: currentUserId, place: detailPlace) { error in
                        if let error = error {
                            print("❌ Error saving place to user's collection: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }

            // Add to user's map places for tracking
            userService.addOrUpdateMapPlace(userId: currentUserId, place: detailPlace) { error in
                if let error = error {
                    print("❌ Error updating map place: \(error)")
                }
            }

            // Store the place for navigation and notify
            createdPlaceForDetail = detailPlace

            // Notify other components to refresh map annotations
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)

            // Notify parent view that a place is successfully saved
            onPlaceSaved?()
            onPlaceSavedWithDetail?(detailPlace)

        } catch {
            print("❌ Failed to save place to database: \(error.localizedDescription)")
        }

        isSavingPlace = false
    }

    /// Fetch place from backend using Google Place ID
    /// Backend handles deduplication - returns existing place or creates new one
    private func fetchPlaceFromBackend(googlePlaceId: String) async throws -> DetailPlace {
        return try await withCheckedThrowingContinuation { continuation in
            mesaBackendService.fetchPlaceDetails(
                placeId: googlePlaceId,
                source: "google"
            ) { result in
                switch result {
                case .success(let place):
                    continuation.resume(returning: place)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Convert a NearbyPlaceFeature to DetailPlace for user-created places only.
    /// Note: For Google Places, use fetchPlaceFromBackend() instead to get proper backend-assigned UUIDs.
    private func convertToDetailPlace(_ nearbyPlace: NearbyPlaceFeature) -> DetailPlace {
        var detailPlace = DetailPlace()

        // For user-created places, generate a UUID from the actualId
        detailPlace.id = createConsistentUUID(from: nearbyPlace.properties.actualId)
        detailPlace.name = nearbyPlace.properties.name
        detailPlace.address = nearbyPlace.properties.address
        detailPlace.coordinate = CLLocationCoordinate2D(
            latitude: nearbyPlace.geometry.latitude,
            longitude: nearbyPlace.geometry.longitude
        )
        detailPlace.rating = nearbyPlace.properties.rating
        detailPlace.userRatingsTotal = nearbyPlace.properties.userRatingsTotal
        detailPlace.categories = nearbyPlace.properties.types
        detailPlace.description = nearbyPlace.properties.description

        if let placeId = nearbyPlace.properties.placeId {
            detailPlace.mapboxId = placeId
        }

        if let priceLevel = nearbyPlace.properties.priceLevel {
            detailPlace.priceLevel = String(priceLevel)
        }

        return detailPlace
    }

    /// Create a consistent UUID from a string identifier.
    /// Used only for user-created places where we need to generate a local ID.
    private func createConsistentUUID(from string: String) -> UUID {
        // Try to parse as UUID first (for existing UUID-based places)
        if let uuid = UUID(uuidString: string) {
            return uuid
        }

        // For user-created places, create a deterministic UUID by hashing the identifier
        let hash = abs(string.hashValue)
        let uuidString = String(format: "%08x-0000-0000-0000-%012x", hash, hash)

        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    func navigateToPlaceDetail(place: DetailPlace) {
        createdPlaceForDetail = place
        shouldNavigateToPlaceDetail = true
        
        // Clear all other states
        showPostCreation = false
        showPlaceSelection = false
    }
    
    /// Saves the selected place to the database after a review is submitted.
    func saveSelectedPlaceAfterReview() async {
        guard let place = resolvedPlace else {
            print("❌ No resolved place to save")
            return
        }

        guard let currentUserId = SupabaseAuthService.shared.currentUserId else {
            print("❌ No authenticated user found")
            return
        }

        isSavingPlace = true

        do {
            // Save to main places collection (upsert - handles deduplication)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                placeService.addToAllPlaces(place: place) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            // For user-created places, also save to myPlaces
            if isUserCreatedPlace {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    placeService.addToMyPlaces(userId: currentUserId, place: place) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }

            // Update map places
            userService.addOrUpdateMapPlace(userId: currentUserId, place: place) { _ in }

            createdPlaceForDetail = place
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)

            onPlaceSaved?()
            onPlaceSavedWithDetail?(place)

        } catch {
            print("❌ Failed to save place: \(error)")
        }

        isSavingPlace = false
    }
    
    func clearSelection() {
        selectedItems = []
        selectedImages = []
        detectedCoordinates = nil
        nearbyPlaces = []
        selectedPlace = nil
        showPlaceSelection = false
        showPostCreation = false
        noLocationDataError = false
        shouldNavigateToPlaceDetail = false
        createdPlaceForDetail = nil
        searchRadiusUsed = 50
        isUserCreatedPlace = false
        isInPhotoImportFlow = false
        resolvedPlace = nil
        isResolvingPlace = false
    }
} 
