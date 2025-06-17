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
    @Published var selectedItem: PhotosPickerItem?
    @Published var selectedImage: UIImage?
    @Published var detectedCoordinates: (latitude: Double, longitude: Double)?
    @Published var isProcessingPhoto: Bool = false
    @Published var nearbyPlaces: [NearbyPlaceFeature] = []
    @Published var isLoadingNearbyPlaces: Bool = false
    @Published var showPlaceSelection: Bool = false
    @Published var selectedPlace: NearbyPlaceFeature?
    
    private let nearbyPlacesService = NearbyPlacesService()
    
    func processSelectedPhoto() async {
        guard let selectedItem = selectedItem else { return }
        
        isProcessingPhoto = true
        
        do {
            // Load the image data
            if let imageData = try await selectedItem.loadTransferable(type: Data.self) {
                selectedImage = UIImage(data: imageData)
                
                // Extract coordinates from photo metadata
                await extractCoordinatesFromPhoto(data: imageData)
            }
        } catch {
            print("Failed to load photo: \(error.localizedDescription)")
        }
        
        isProcessingPhoto = false
    }
    
    private func extractCoordinatesFromPhoto(data: Data) async {
        print("📸 Starting coordinate extraction...")
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("❌ Failed to get image properties")
            detectedCoordinates = nil
            return
        }
        
        print("✅ Got image properties")
        
        guard let gpsData = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            print("❌ No GPS data found in photo")
            detectedCoordinates = nil
            return
        }
        
        print("✅ Found GPS data: \(gpsData)")
        
        // Extract GPS coordinates
        if let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
           let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double,
           let latitudeRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String {
            
            let finalLatitude = (latitudeRef == "S") ? -latitude : latitude
            let finalLongitude = (longitudeRef == "W") ? -longitude : longitude
            
            detectedCoordinates = (latitude: finalLatitude, longitude: finalLongitude)
            print("🎯 Extracted coordinates: \(finalLatitude), \(finalLongitude)")
            
            // Fetch nearby places
            await fetchNearbyPlaces(latitude: finalLatitude, longitude: finalLongitude)
        } else {
            print("❌ Failed to parse coordinate values")
            detectedCoordinates = nil
        }
    }
    
    func fetchNearbyPlaces(latitude: Double, longitude: Double) async {
        isLoadingNearbyPlaces = true
        
        do {
            let response = try await nearbyPlacesService.fetchNearbyPlaces(
                latitude: latitude,
                longitude: longitude
            )
            
            nearbyPlaces = response.features
            print("🏢 Found \(nearbyPlaces.count) nearby places")
            
            if nearbyPlaces.isEmpty {
                print("❌ No nearby places found - need to create new place")
                // TODO: Handle create new place flow
            } else {
                showPlaceSelection = true
            }
            
        } catch {
            print("❌ Failed to fetch nearby places: \(error)")
        }
        
        isLoadingNearbyPlaces = false
    }
    
    func selectPlace(_ place: NearbyPlaceFeature) {
        selectedPlace = place
        showPlaceSelection = false
        print("✅ Selected place: \(place.properties.name)")
        // TODO: Navigate to review screen with selected place
    }
    
    func clearSelection() {
        selectedItem = nil
        selectedImage = nil
        detectedCoordinates = nil
        nearbyPlaces = []
        selectedPlace = nil
        showPlaceSelection = false
    }
} 