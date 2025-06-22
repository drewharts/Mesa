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
    @Published var showReviewTypeSelection: Bool = false
    @Published var noLocationDataError: Bool = false
    @Published var shouldNavigateToPlaceDetail: Bool = false
    @Published var createdPlaceForDetail: DetailPlace?
    @Published var searchRadiusUsed: Int = 50
    
    private let nearbyPlacesService = NearbyPlacesService()
    
    func processSelectedPhotos() async {
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
                }
            }
            
        } catch {
            print("Failed to load photos: \(error.localizedDescription)")
            await MainActor.run {
                showPlaceSelection = false
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
            
            // If no places found, try with larger radius (100m)
            if nearbyPlaces.isEmpty {
                print("🔍 No places found within 50m, expanding search to 100m...")
                response = try await nearbyPlacesService.fetchNearbyPlaces(
                    latitude: latitude,
                    longitude: longitude,
                    radiusMeters: 100
                )
                
                nearbyPlaces = response.features
                print("🏢 Found \(nearbyPlaces.count) places within 100m")
                
                if nearbyPlaces.isEmpty {
                    print("❌ No nearby places found even within 100m - user can create new place")
                    searchRadiusUsed = 100
                } else {
                    print("✅ Expanded search successful - found places within 100m")
                    searchRadiusUsed = 100
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
        showReviewTypeSelection = true
        print("✅ Selected place: \(place.properties.name)")
    }
    
    func navigateToPlaceDetail(place: DetailPlace) {
        createdPlaceForDetail = place
        shouldNavigateToPlaceDetail = true
        
        // Clear all other states
        showReviewTypeSelection = false
        showPlaceSelection = false
    }
    
    func clearSelection() {
        selectedItems = []
        selectedImages = []
        detectedCoordinates = nil
        nearbyPlaces = []
        selectedPlace = nil
        showPlaceSelection = false
        showReviewTypeSelection = false
        noLocationDataError = false
        shouldNavigateToPlaceDetail = false
        createdPlaceForDetail = nil
        searchRadiusUsed = 50
    }
} 