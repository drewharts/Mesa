//
//  FavoritePlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//


// FavoritePlaceViewModel.swift
import Foundation
import GooglePlaces
import Combine
import SwiftUI

class FavoritePlaceViewModel: ObservableObject, Identifiable {
    let id: String // placeID
    let place: Place
    @Published var gmsPlace: GMSPlace? = nil
    @Published var placeImage: UIImage? = nil
    
    private let googlePlacesService = GooglePlacesService()
    private var cancellables = Set<AnyCancellable>()
    
    init(place: Place) {
        self.place = place
        self.id = place.id.uuidString
//        fetchGMSPlace()
    }
    
//    private func fetchGMSPlace() {
//        googlePlacesService.fetchPlace(placeID: place.id) { [weak self] gmsPlace, error in
//            // Handle error if needed
//            if let error = error {
//                print("Error fetching GMSPlace: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let self = self, let gmsPlace = gmsPlace else {
//                print("GMSPlace is nil.")
//                return
//            }
//            
//            DispatchQueue.main.async {
//                self.gmsPlace = gmsPlace
//                self.fetchPlacePhoto()
//            }
//        }
//        print("Fetched place \(gmsPlace?.name ?? "?"): \(gmsPlace?.phoneNumber ?? "No phone")")
//
//    }

    
    private func fetchPlacePhoto() {
        guard let gmsPlace = gmsPlace,
              let photoMetadata = gmsPlace.photos?.first else { return }
        
        googlePlacesService.fetchPhoto(placeID: gmsPlace.placeID ?? "") { [weak self] image in
            DispatchQueue.main.async {
                self?.placeImage = image
            }
        }
    }
}
