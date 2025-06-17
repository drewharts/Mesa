//  PhotoImportViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import PhotosUI
import CoreLocation
import ImageIO

@MainActor
class PhotoImportViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published var selectedImage: UIImage?
    @Published var detectedLocation: CLLocation?
    @Published var detectedPlaceName: String?
    @Published var isProcessingPhoto: Bool = false
    @Published var isLocationDetectionEnabled: Bool = true
    @Published var showLocationAlert: Bool = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    init() {
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func processSelectedPhoto() async {
        guard let selectedItem = selectedItem else { return }
        
        isProcessingPhoto = true
        errorMessage = nil
        
        do {
            // Load the image data
            if let imageData = try await selectedItem.loadTransferable(type: Data.self) {
                selectedImage = UIImage(data: imageData)
                
                // Extract location from photo metadata
                await extractLocationFromPhoto(data: imageData)
            }
        } catch {
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
        }
        
        isProcessingPhoto = false
    }
    
    private func extractLocationFromPhoto(data: Data) async {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let gpsData = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            
            // No GPS data found in photo, optionally use current location
            if isLocationDetectionEnabled {
                await useCurrentLocation()
            }
            return
        }
        
        // Extract GPS coordinates
        if let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
           let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double,
           let latitudeRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String {
            
            let finalLatitude = (latitudeRef == "S") ? -latitude : latitude
            let finalLongitude = (longitudeRef == "W") ? -longitude : longitude
            
            detectedLocation = CLLocation(latitude: finalLatitude, longitude: finalLongitude)
            
            // Reverse geocode to get place name
            await reverseGeocodeLocation()
        }
    }
    
    private func useCurrentLocation() async {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            showLocationAlert = true
            return
        }
        
        // Get current location
        if let currentLocation = locationManager.location {
            detectedLocation = currentLocation
            await reverseGeocodeLocation()
        }
    }
    
    private func reverseGeocodeLocation() async {
        guard let location = detectedLocation else { return }
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                detectedPlaceName = formatPlaceName(from: placemark)
            }
        } catch {
            errorMessage = "Failed to detect place name: \(error.localizedDescription)"
        }
    }
    
    private func formatPlaceName(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    func clearSelection() {
        selectedItem = nil
        selectedImage = nil
        detectedLocation = nil
        detectedPlaceName = nil
        errorMessage = nil
    }
    
    func createReviewWithDetectedLocation() {
        // TODO: Integrate with review creation flow
        // This method will be called when user wants to create a review
        // with the detected location and photo
    }
} 