//
//  RestaurantDetailViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//

import SwiftUI
import MapKit
import MapboxSearch
import UIKit

class PlaceDetailViewModel: ObservableObject {
    @Published var photos: [UIImage] = []
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var showListSelection = false
    @Published var phoneNumber = ""
    @Published var placeName: String = "Unknown"
    @Published var openingHours: [String]?
    @Published var isOpen: Bool = false
    @Published var travelTime: String = "Calculating..."
    @Published var currentTransportType: MapKitService.TransportType = .automobile
    @Published var travelTimes: [MapKitService.TransportType: String] = [:]

    
    var placeIconURL: URL?
    /// Keep track of which place we've loaded, so we don't fetch again unnecessarily.
    private(set) var currentPlaceID: String?

    init() {
        loadDefaultTransportType()
        // Empty. We'll call loadData(for:) later.
    }

    private func loadDefaultTransportType() {
        let savedTypeRaw = UserDefaults.standard.integer(forKey: "defaultTransportType")
        if let transportType = MapKitService.TransportType(rawValue: savedTypeRaw) {
            currentTransportType = transportType
        } else {
            currentTransportType = .automobile // Default to automobile
        }
    }

    func saveDefaultTransportType(_ transportType: MapKitService.TransportType) {
        UserDefaults.standard.set(transportType.rawValue, forKey: "defaultTransportType")
        currentTransportType = transportType
    }

    func loadData(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        // If we already loaded this place, do nothing (optional).
        if currentPlaceID == place.id.uuidString { return }
        
        self.currentPlaceID = place.id.uuidString
        
        print("🔄 [PlaceDetailViewModel] loadData: Setting placeName to '\(place.name)'")
        self.placeName = place.name
        self.updateTravelTime(for: place, from: currentLocation)
    }
    
    func updatePlaceData(_ place: DetailPlace) {
        // Update the place data when SelectedPlaceViewModel gets complete details
        // Update currentPlaceID if it's different (indicates a new place was selected)
        if currentPlaceID != place.id.uuidString {
            print("🔄 [PlaceDetailViewModel] updatePlaceData: New place detected, updating currentPlaceID")
            currentPlaceID = place.id.uuidString
        }
        
        print("🔄 [PlaceDetailViewModel] updatePlaceData: Setting placeName to '\(place.name)'")
        self.placeName = place.name
        // Add any other place properties that need to be updated here
    }
    
    func openNavigation(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        // Unwrap the coordinate
        guard let destinationCoordinate = place.coordinate else {
            print("No coordinate available for this place.")
            return
        }

        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        destinationMapItem.name = place.name

        // Create a map item for the current location.
        let currentLocationMapItem = MKMapItem.forCurrentLocation()

        // Define launch options based on current transport type.
        var launchOptions: [String: Any] = [:]

        print("🗺️ [PlaceDetailViewModel] Opening navigation with transport type: \(currentTransportType.displayName)")

        switch currentTransportType {
        case .automobile:
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
            print("🚗 [PlaceDetailViewModel] Using driving directions")
        case .walking:
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
            print("🚶 [PlaceDetailViewModel] Using walking directions")
        case .transit:
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit]
            print("🚇 [PlaceDetailViewModel] Using transit directions")
        case .bicycle:
            // MapKit doesn't have bicycle directions, so we'll use walking directions
            // which is better than driving directions for cyclists
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
            print("🚴 [PlaceDetailViewModel] Using walking directions for bicycle (best available)")
        }

        // Launch Apple Maps with the specified options.
        MKMapItem.openMaps(with: [currentLocationMapItem, destinationMapItem], launchOptions: launchOptions)
    }
    
//    private func fetchPhotos(for place: GMSPlace) {
//        photos = []
//        
//        guard let photosMetadata = place.photos, !photosMetadata.isEmpty else {
//            print("No photos metadata found.")
//            return
//        }
//
//        let placesClient = GMSPlacesClient.shared()
//
//        photosMetadata.forEach { metadata in
//            let request = GMSFetchPhotoRequest(
//                photoMetadata: metadata,
//                maxSize: CGSize(width: 480, height: 480)
//            )
//
//            placesClient.fetchPhoto(with: request) { [weak self] image, error in
//                guard let self = self else { return }
//                if let error = error {
//                    print("Error fetching photo: \(error.localizedDescription)")
//                    return
//                }
//                if let image = image {
//                    DispatchQueue.main.async {
//                        // Double check the placeID to ensure we haven't switched
//                        if self.currentPlaceID == place.placeID {
//                            self.photos.append(image)
//                        }
//                    }
//                }
//            }
//        }
//    }
    
    func updateTravelTime(for place: DetailPlace, from userCoordinate: CLLocationCoordinate2D) {
        // Unwrap the coordinate; if it's nil, set travelTime to "N/A" and return.
        guard let placeCoordinate = place.coordinate else {
            DispatchQueue.main.async { [weak self] in
                self?.travelTime = "N/A"
                self?.travelTimes = [:]
            }
            return
        }

        // Calculate travel times for all transport types
        MapKitService.shared.calculateTravelTimes(from: userCoordinate, to: placeCoordinate) { [weak self] results, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.travelTime = "N/A"
                    self?.travelTimes = [:]
                } else if let results = results {
                    var times: [MapKitService.TransportType: String] = [:]

                    for (transportType, timeInterval) in results {
                        let minutes = timeInterval / 60.0
                        let timeString = minutes > 60 ? "60+ min" : String(format: "%.0f min", minutes)
                        times[transportType] = timeString
                    }

                    self?.travelTimes = times

                    // Set the current travel time based on current transport type
                    if let currentTime = times[self?.currentTransportType ?? .automobile] {
                        self?.travelTime = currentTime
                    } else {
                        self?.travelTime = "N/A"
                    }
                } else {
                    self?.travelTime = "N/A"
                    self?.travelTimes = [:]
                }
            }
        }
    }

    func switchTransportType(to transportType: MapKitService.TransportType) {
        self.currentTransportType = transportType
        if let timeString = travelTimes[transportType] {
            self.travelTime = timeString
        } else {
            self.travelTime = "Calculating..."
        }
    }
    
    // Some convenience methods
    func handleAddButton() {
        showListSelection = true
    }
    
    func showDirections() {
        // directions logic
    }

    func getRestaurantType(for place: DetailPlace) -> String? {
        // Add safety guards to prevent crashes
        guard let placeTypes = place.categories,
              !placeTypes.isEmpty else { 
            return PlaceTypes.defaultType 
        }
        
        // Make a defensive copy to avoid potential race conditions
        let placeTypesCopy = Array(placeTypes)
        let recognizedTypesCopy = Array(PlaceTypes.recognizedTypes)
        
        // First pass: Look for specific cuisine types (prioritize over generic terms)
        // Skip generic terms in first pass - these will be checked in second pass only
        let genericTerms = [
            "Restaurant", "Cafe", "Bar", "Place",
            "Point of Interest", "Point Of Interest", "Point_of_Interest", 
            "POI", "Establishment", "Store", "Business", "Location",
            "Venue", "Site", "Spot", "Destination"
        ]
        for recognizedType in recognizedTypesCopy {
            // Skip generic terms in first pass (normalize for comparison)
            let normalizedRecognizedType = recognizedType.lowercased()
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: ".", with: " ")
            
            let isGenericTerm = genericTerms.contains { genericTerm in
                let normalizedGenericTerm = genericTerm.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                return normalizedRecognizedType == normalizedGenericTerm
            }
            
            if isGenericTerm { continue }
            
            guard !recognizedType.isEmpty else { continue }
            
            if placeTypesCopy.contains(where: { placeType in
                guard !placeType.isEmpty else { return false }
                
                // Normalize both strings for better matching
                let normalizedPlaceType = placeType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                let normalizedRecognizedType = recognizedType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                guard !normalizedPlaceType.isEmpty && !normalizedRecognizedType.isEmpty else {
                    return false
                }
                
                // Check if the place type contains the cuisine type
                // e.g., "indian restaurant" contains "indian"
                return normalizedPlaceType.contains(normalizedRecognizedType)
            }) {
                return recognizedType
            }
        }
        
        // Second pass: Look for generic terms if no specific type found
        // Check both our generic terms and any generic terms from the recognized types
        var allGenericTermsToCheck = genericTerms
        
        // Add any generic terms from recognized types that we skipped in first pass
        for recognizedType in recognizedTypesCopy {
            let normalizedRecognizedType = recognizedType.lowercased()
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: ".", with: " ")
            
            let isGenericTerm = genericTerms.contains { genericTerm in
                let normalizedGenericTerm = genericTerm.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                return normalizedRecognizedType == normalizedGenericTerm
            }
            
            if isGenericTerm && !allGenericTermsToCheck.contains(recognizedType) {
                allGenericTermsToCheck.append(recognizedType)
            }
        }
        
        for genericTerm in allGenericTermsToCheck {
            if placeTypesCopy.contains(where: { placeType in
                guard !placeType.isEmpty else { return false }
                
                let normalizedPlaceType = placeType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                let normalizedGenericTerm = genericTerm.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                guard !normalizedPlaceType.isEmpty && !normalizedGenericTerm.isEmpty else {
                    return false
                }
                
                return normalizedPlaceType.contains(normalizedGenericTerm)
            }) {
                // Return the original generic term from our list if found, not the recognized type variant
                return genericTerm
            }
        }
        
        return PlaceTypes.defaultType
    }

    func openInGoogleMaps(latitude: Double, longitude: Double) {
        let googleMapsURL = URL(string: "comgooglemaps://?center=\(latitude),\(longitude)&zoom=14")!
        let fallbackURL = URL(string: "https://maps.google.com/?q=\(latitude),\(longitude)")!
        
        // Check if the Google Maps app can be opened
        if UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL, options: [:], completionHandler: nil)
        } else {
            // Fallback to opening in browser if the app isn't installed
            UIApplication.shared.open(fallbackURL, options: [:], completionHandler: nil)
        }
    }

    func openGoogleMapsWithPlace(query: String) {
        // Encode the query to handle spaces and special characters
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let googleMapsURL = URL(string: "comgooglemaps://?q=\(encodedQuery)") else { return }
        let fallbackURL = URL(string: "https://maps.google.com/?q=\(encodedQuery)")!
        
        if UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.open(fallbackURL, options: [:], completionHandler: nil)
        }
    }
}
