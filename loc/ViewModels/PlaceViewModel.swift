//
//  PlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//


// PlaceViewModel.swift
import Foundation
import GooglePlaces
import Combine
import SwiftUI

class PlaceViewModel: ObservableObject, Identifiable {
    let id: String // placeID
    let place: Place
    @Published var gmsPlace: GMSPlace? = nil
    @Published var placeImage: UIImage? = nil

    // Optional: Error handling
    @Published var hasError: Bool = false
    @Published var errorMessage: String = ""

    private let googlePlacesService = GooglePlacesService()
    private var cancellables = Set<AnyCancellable>()

    init(place: Place) {
        self.place = place
        self.id = place.id.uuidString
//        fetchGMSPlace()
    }

//    private func fetchGMSPlace() {
//        googlePlacesService.fetchPlace(placeID: place.id) { [weak self] gmsPlace, error in
//            if let error = error {
//                print("Error fetching GMSPlace: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    self?.hasError = true
//                    self?.errorMessage = error.localizedDescription
//                }
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
