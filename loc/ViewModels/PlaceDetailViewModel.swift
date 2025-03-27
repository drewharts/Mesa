//
//  RestaurantDetailViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//

import SwiftUI
import MapKit
import MapboxSearch

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
    /// Keep track of which place we've loaded, so we don’t fetch again unnecessarily.
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
            "Italian", "Chinese", "Greek", "Vietnamese"
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
}
