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

    
    var placeIconURL: URL?
    /// Keep track of which place we've loaded, so we don't fetch again unnecessarily.
    private(set) var currentPlaceID: String?

    init() {
        // Empty. We'll call loadData(for:) later.
    }

    func loadData(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        // If we already loaded this place, do nothing (optional).
        if currentPlaceID == place.id.uuidString { return }
        
        self.currentPlaceID = place.id.uuidString
        
        self.placeName = place.name ?? "Restaurant"
        self.updateTravelTime(for: place, from: currentLocation)
    }
    
    func openNavigation(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        // Unwrap the GeoPoint from place.coordinate
        guard let geoPoint = place.coordinate else {
            print("No coordinate available for this place.")
            return
        }
        
        // Convert GeoPoint to CLLocationCoordinate2D.
        let destinationCoordinate = CLLocationCoordinate2D(
            latitude: geoPoint.latitude,
            longitude: geoPoint.longitude
        )
        
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        destinationMapItem.name = place.name
        
        // Create a map item for the current location.
        let currentLocationMapItem = MKMapItem.forCurrentLocation()
        
        // Define launch options for driving directions.
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        
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
        // Unwrap the GeoPoint; if it's nil, set travelTime to "N/A" and return.
        guard let geoPoint = place.coordinate else {
            DispatchQueue.main.async { [weak self] in
                self?.travelTime = "N/A"
            }
            return
        }
        
        // Convert GeoPoint to CLLocationCoordinate2D.
        let placeCoordinate = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
        
        MapKitService.shared.calculateTravelTime(from: userCoordinate, to: placeCoordinate) { [weak self] timeInterval, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error calculating travel time: \(error.localizedDescription)")
                    self?.travelTime = "N/A"
                } else if let timeInterval = timeInterval {
                    let minutes = timeInterval / 60.0
                    self?.travelTime = minutes > 60 ? "60+ min" : String(format: "%.0f min", minutes)
                } else {
                    self?.travelTime = "N/A"
                }
            }
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
        let recognizedTypes = [
            "American", "Japanese", "Korean", "Mexican",
            "Italian", "Chinese", "Greek", "Vietnamese",
            "Barbecue", "Indian", "Clothing", "Grocery", "Hotel",
            "Bookstore", "Pharmacy", "Library", "Bakery", "Convenience Store",
            "Clothes", "Pizza", "Coffee Shop", "Steakhouse"
        ]
        //TODO: this may need some revision at a later date
        guard let placeTypes = place.categories else { return nil }
        for recognizedType in recognizedTypes {
            if placeTypes.contains(where: {
                $0.lowercased().contains(recognizedType.lowercased())
            }) {
                return recognizedType
            }
        }
        return nil
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
