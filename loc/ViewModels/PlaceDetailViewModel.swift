//
//  RestaurantDetailViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//


import SwiftUI
import GooglePlaces

class PlaceDetailViewModel: ObservableObject {
    @Published var photos: [UIImage] = []
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var showListSelection = false
    @Published var phoneNumber = ""
    @Published var placeName: String = "Unknown"
    @Published var openingHours: [String]?
    
    var placeIconURL: URL?
    
    /// Keep track of which place we've loaded, so we don’t fetch again unnecessarily.
    private(set) var currentPlaceID: String?

    init() {
        // Empty. We'll call loadData(for:) later.
    }

    func loadData(for place: GMSPlace) {
        // If we already loaded this place, do nothing (optional).
        if currentPlaceID == place.placeID { return }
        
        self.currentPlaceID = place.placeID
        
        DispatchQueue.main.async {
            self.placeName = place.name ?? "Restaurant"
            self.placeIconURL = place.iconImageURL
            self.openingHours = place.currentOpeningHours?.weekdayText
            self.phoneNumber = place.phoneNumber ?? ""
            self.fetchPhotos(for: place)
        }
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
