//
//  RestaurantDetailViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//

import SwiftUI
import GooglePlaces
import MapKit

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
    let googleplacesService = GooglePlacesService()
    /// Keep track of which place we've loaded, so we don’t fetch again unnecessarily.
    private(set) var currentPlaceID: String?

    init() {
        // Empty. We'll call loadData(for:) later.
    }

    func loadData(for place: GMSPlace, currentLocation: CLLocationCoordinate2D) {
        // If we already loaded this place, do nothing (optional).
        if currentPlaceID == place.placeID { return }
        
        self.currentPlaceID = place.placeID
        
        DispatchQueue.main.async {
            self.placeName = place.name ?? "Restaurant"
            self.placeIconURL = place.iconImageURL
            self.openingHours = place.currentOpeningHours?.weekdayText
            self.phoneNumber = place.phoneNumber ?? ""
            self.fetchPhotos(for: place)
            // Replace the deprecated call:
            // place.isOpen()
            self.checkOpenStatus(for: place)
            self.updateTravelTime(for: place, from: currentLocation)
        }
    }
    
    func openNavigation(for place: GMSPlace, currentLocation: CLLocationCoordinate2D) {
        let destinationCoordinate = place.coordinate // Assuming GMSPlace exposes a coordinate property.
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
    
    private func fetchPhotos(for place: GMSPlace) {
        photos = []
        
        guard let photosMetadata = place.photos, !photosMetadata.isEmpty else {
            print("No photos metadata found.")
            return
        }

        let placesClient = GMSPlacesClient.shared()

        photosMetadata.forEach { metadata in
            let request = GMSFetchPhotoRequest(
                photoMetadata: metadata,
                maxSize: CGSize(width: 480, height: 480)
            )

            placesClient.fetchPhoto(with: request) { [weak self] image, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching photo: \(error.localizedDescription)")
                    return
                }
                if let image = image {
                    DispatchQueue.main.async {
                        // Double check the placeID to ensure we haven't switched
                        if self.currentPlaceID == place.placeID {
                            self.photos.append(image)
                        }
                    }
                }
            }
        }
    }
    
    func updateTravelTime(for place: GMSPlace, from userCoordinate: CLLocationCoordinate2D) {
        let placeCoordinate = place.coordinate // Assuming GMSPlace has a `coordinate` property.
        MapKitService.shared.calculateTravelTime(from: userCoordinate, to: placeCoordinate) { [weak self] timeInterval, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error calculating travel time: \(error.localizedDescription)")
                    self?.travelTime = "N/A"
                } else if let timeInterval = timeInterval {
                    let minutes = timeInterval / 60.0
                    if minutes > 60 {
                        self?.travelTime = "60+ min"
                    } else {
                        self?.travelTime = String(format: "%.0f min", minutes)
                    }
                } else {
                    self?.travelTime = "N/A"
                }
            }
        }
    }
    
    
    
    /// Checks if the restaurant is open right now using the recommended isOpen API.
    private func checkOpenStatus(for place: GMSPlace) {
        googleplacesService.isRestaurantOpenNow(placeID: place.placeID!) { [weak self] isOpen, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    print("Error checking open status: \(error.localizedDescription)")
                    self.isOpen = false
                } else {
                    self.isOpen = isOpen
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

    func getRestaurantType(for place: GMSPlace) -> String? {
        let recognizedTypes = [
            "American", "Japanese", "Korean", "Mexican",
            "Italian", "Chinese", "Greek", "Vietnamese"
        ]
        
        guard let placeTypes = place.types else { return nil }
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
