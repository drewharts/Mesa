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
    
    private let nearbyPlacesService = NearbyPlacesService()
    private let placeService = PlaceService.shared
    private let userService = UserService.shared
    
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
                    print("📸 Checking photo \(index + 1) for GPS coordinates...")
                    
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
        print("📸 Starting coordinate extraction for photo \(photoIndex)...")
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("❌ Failed to get image properties for photo \(photoIndex)")
            return false
        }
        
        print("✅ Got image properties for photo \(photoIndex)")
        
        guard let gpsData = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            print("❌ No GPS data found in photo \(photoIndex)")
            return false
        }
        
        print("✅ Found GPS data in photo \(photoIndex): \(gpsData)")
        
        // Extract GPS coordinates
        if let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
           let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double,
           let latitudeRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String {
            
            let finalLatitude = (latitudeRef == "S") ? -latitude : latitude
            let finalLongitude = (longitudeRef == "W") ? -longitude : longitude
            
            detectedCoordinates = (latitude: finalLatitude, longitude: finalLongitude)
            print("🎯 Extracted coordinates from photo \(photoIndex): \(finalLatitude), \(finalLongitude)")
            
            // Fetch nearby places
            await fetchNearbyPlaces(latitude: finalLatitude, longitude: finalLongitude)
            return true
        } else {
            print("❌ Failed to parse coordinate values from photo \(photoIndex)")
            return false
        }
    }
    
    func fetchNearbyPlaces(latitude: Double, longitude: Double) async {
        isLoadingNearbyPlaces = true
        
        do {
            // First try with default radius (50m)
            print("🔍 Searching for nearby places within 50m...")
            var response = try await nearbyPlacesService.fetchNearbyPlaces(
                latitude: latitude,
                longitude: longitude,
                radiusMeters: 50
            )
            
            nearbyPlaces = response.features
            print("🏢 Found \(nearbyPlaces.count) places within 50m")
            
            // If no places found, try with larger radius (250m)
            if nearbyPlaces.isEmpty {
                print("🔍 No places found within 50m, expanding search to 250m...")
                response = try await nearbyPlacesService.fetchNearbyPlaces(
                    latitude: latitude,
                    longitude: longitude,
                    radiusMeters: 250
                )
                
                nearbyPlaces = response.features
                print("🏢 Found \(nearbyPlaces.count) places within 250m")
                
                // If still no places found, try with even larger radius (1000m)
                if nearbyPlaces.isEmpty {
                    print("🔍 No places found within 250m, expanding search to 1000m...")
                    response = try await nearbyPlacesService.fetchNearbyPlaces(
                        latitude: latitude,
                        longitude: longitude,
                        radiusMeters: 1000
                    )
                    
                    nearbyPlaces = response.features
                    print("🏢 Found \(nearbyPlaces.count) places within 1000m")
                    
                    if nearbyPlaces.isEmpty {
                        print("❌ No nearby places found even within 1000m - user can create new place")
                        searchRadiusUsed = 1000
                    } else {
                        print("✅ Expanded search successful - found places within 1000m")
                        searchRadiusUsed = 1000
                    }
                } else {
                    print("✅ Expanded search successful - found places within 250m")
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
    
    func selectPlace(_ place: NearbyPlaceFeature) {
        selectedPlace = place
        showPlaceSelection = false
        showPostCreation = true
        
        // Track if this is a user-created place (will be saved later when review is submitted)
        isUserCreatedPlace = place.properties.source == "user_created"
        
        print("✅ Selected place: \(place.properties.name)")
        print("📝 User-created place: \(isUserCreatedPlace)")
        
        // Note: Place will be saved to Firestore only when review is submitted
    }
    
    private func saveSelectedPlaceToFirestore(_ nearbyPlace: NearbyPlaceFeature) async {
        guard let currentUserId = SupabaseAuthService.shared.currentUserId else {
            print("❌ No authenticated user found")
            return
        }
        
        isSavingPlace = true
        
        do {
            // Convert NearbyPlaceFeature to DetailPlace
            let detailPlace = convertToDetailPlace(nearbyPlace)
            
            // Save to main places collection
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                placeService.addToAllPlaces(place: detailPlace) { error in
                    if let error = error {
                        print("❌ Error saving place to main collection: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        print("✅ Successfully saved place to main collection")
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
                            print("✅ Successfully saved place to user's myPlaces collection")
                            continuation.resume()
                        }
                    }
                }
            }
            
            // Add to user's map places for tracking
            userService.addOrUpdateMapPlace(userId: currentUserId, place: detailPlace) { error in
                if let error = error {
                    print("❌ Error updating map place: \(error)")
                } else {
                    print("✅ Successfully updated map place")
                }
            }
            
            // Notify other components to refresh map annotations
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
            
            print("✅ Place '\(detailPlace.name)' successfully saved to Firestore")
            
            // Notify parent view that a place is successfully saved
            onPlaceSaved?()
            onPlaceSavedWithDetail?(detailPlace)
            
        } catch {
            print("❌ Failed to save place to Firestore: \(error.localizedDescription)")
        }
        
        isSavingPlace = false
    }
    
    private func convertToDetailPlace(_ nearbyPlace: NearbyPlaceFeature) -> DetailPlace {
        var detailPlace = DetailPlace()
        
        // TODO: This should use the backend to get/assign place IDs instead of creating them locally
        // RISK: Hash-based UUIDs might not match backend-assigned UUIDs, causing duplicate places
        // Create a consistent UUID from the actualId by hashing it
        detailPlace.id = createConsistentUUID(from: nearbyPlace.properties.actualId)
        detailPlace.name = nearbyPlace.properties.name
        detailPlace.address = nearbyPlace.properties.address
        detailPlace.coordinate = CLLocationCoordinate2D(
            latitude: nearbyPlace.geometry.latitude,
            longitude: nearbyPlace.geometry.longitude
        )
        detailPlace.rating = nearbyPlace.properties.rating
        detailPlace.categories = nearbyPlace.properties.types
        detailPlace.description = nearbyPlace.properties.description
        
        // Handle Google Places specific data
        if let placeId = nearbyPlace.properties.placeId {
            detailPlace.mapboxId = placeId // Using mapboxId field for Google Place ID
        }
        
        // Handle price level
        if let priceLevel = nearbyPlace.properties.priceLevel {
            detailPlace.priceLevel = String(priceLevel)
        }
        
        return detailPlace
    }
    
    private func createConsistentUUID(from string: String) -> UUID {
        // Try to parse as UUID first (for existing UUID-based places)
        if let uuid = UUID(uuidString: string) {
            return uuid
        }
        
        // TODO: This hash-based approach is problematic
        // The backend might assign different UUIDs for the same place, causing duplicates
        // BETTER APPROACH: Send the Google Place ID to backend, let it assign/find the UUID
        
        // For non-UUID strings (like Google Place IDs), create a consistent UUID by hashing
        // This ensures the same string always produces the same UUID
        let hash = abs(string.hashValue)
        
        // Create a deterministic UUID from the hash
        // We'll use the hash to seed the UUID generation
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
    
    // Called when a review is submitted to save the place to Firestore
    func saveSelectedPlaceAfterReview() async {
        guard let place = selectedPlace else {
            print("❌ No selected place to save")
            return
        }
        
        // Only save if this is a user-created place (existing places are already in Firestore)
        if !isUserCreatedPlace {
            // Existing place selected from API – ensure it's in Firestore & user collections
            print("💾 Saving existing selected place after review submission: \(place.properties.name)")
            await saveSelectedPlaceToFirestore(place)
        } else {
            print("ℹ️ Skipping extra save for newly-created place: \(place.properties.name)")
        }
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
    }
} 
