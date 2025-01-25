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

    private var currentPlaceID: String?

    var placeName: String = "Unknown"
    var placeIconURL: URL?
    var openingHours: [String]?

    func loadData(for place: GMSPlace) {
        placeName = place.name ?? "Restuarant"
        placeIconURL = place.iconImageURL
        openingHours = place.currentOpeningHours?.weekdayText
        fetchPhotos(for: place)
    }
    
    func getRestaurantType(for place: GMSPlace) -> String? {
        let recognizedTypes = ["American", "Japanese", "Korean", "Mexican", "Italian", "Chinese", "Greek", "Vietnamese"]
        
        // Get the types from the GMSPlace (e.g., ["japanese_restaurant", "sushi"]).
        guard let placeTypes = place.types else {
            return nil
        }
        
        // Look for the first recognized type that appears in any of the place’s types.
        //    We do a `.lowercased()` check so it’s case‐insensitive.
        for recognizedType in recognizedTypes {
            // If any string in `placeTypes` contains the recognizedType (e.g. “japanese” in “japanese_restaurant”)
            if placeTypes.contains(where: { $0.lowercased().contains(recognizedType.lowercased()) }) {
                return recognizedType
            }
        }
        
        // 4. If no match found, return nil
        return nil
    }


    func fetchPhotos(for place: GMSPlace) {
        photos = []
        guard let photosMetadata = place.photos, !photosMetadata.isEmpty else {
            print("No photos metadata found.")
            return
        }

        currentPlaceID = place.placeID

        let placesClient = GMSPlacesClient.shared()

        photosMetadata.forEach { photoMetadata in
            let fetchPhotoRequest = GMSFetchPhotoRequest(photoMetadata: photoMetadata, maxSize: CGSize(width: 480, height: 480))
            
            placesClient.fetchPhoto(with: fetchPhotoRequest) { [weak self] photoImage, error in
                if let error = error {
                    print("Error fetching photo: \(error.localizedDescription)")
                } else if let photoImage = photoImage {
                    DispatchQueue.main.async {
                        if self?.currentPlaceID == place.placeID {
                            self?.photos.append(photoImage)
                        } else {
                            print("Discarding photo for outdated place.")
                        }
                    }
                }
            }
        }
    }

    func handleAddButton() {
        showListSelection = true
    }

    func showDirections() {
        // Handle directions logic
    }
}
