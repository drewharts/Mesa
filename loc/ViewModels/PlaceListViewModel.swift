//
//  PlaceListViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import Foundation
import GooglePlaces
import UIKit
import FirebaseStorage
import Combine

class PlaceListViewModel: ObservableObject, Identifiable {
    @Published var placeList: PlaceList
    @Published var placeViewModels: [PlaceViewModel] = []
    private let firestoreService: FirestoreService
    private let userId: String
    @Published var image: UIImage?
    private var cancellables = Set<AnyCancellable>()


    init(placeList: PlaceList, firestoreService: FirestoreService, userId: String) {
        self.placeList = placeList
        self.firestoreService = firestoreService
        self.userId = userId
        loadPlaceLists()
        loadImage()
    }
    
    func getImage() -> UIImage? {
        return image
    }

    // Load the place lists from Firestore.
    func loadPlaceLists() {
        firestoreService.fetchList(userId: userId, listName: placeList.name) { [weak self] result in
            switch result {
            case .success(let fetchedPlaceList):
                DispatchQueue.main.async {
                    self?.placeList = fetchedPlaceList
                    self?.placeViewModels = fetchedPlaceList.places.map { place in
                        PlaceViewModel(place: place)
                    }
                }
            case .failure(let error):
                print("Failed to load place list: \(error.localizedDescription)")
            }
        }
    }


    
    func loadImage() {
        guard let imageURLString = placeList.image as? String,
              let imageURL = URL(string: imageURLString) else {
            self.image = nil
            return
        }
        
        fetchImage(from: imageURL) { [weak self] fetchedImage in
            self?.image = fetchedImage
        }
    }

    private func fetchImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                print("Failed to fetch image: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }




    func addPlace(_ place: GMSPlace) {
        if let placeID = place.placeID {
            let newPlace = Place(
                id: placeID,
                name: place.name ?? "",
                address: place.formattedAddress ?? ""
            )
            placeViewModels.append(PlaceViewModel(place: newPlace))
            placeList.places.append(newPlace)
            firestoreService.addPlaceToList(userId: userId, listName: placeList.name, place: newPlace)
        }
    }

    func removePlace(_ place: GMSPlace) {
        if let placeID = place.placeID {
            // Remove from local view models
            if let index = placeViewModels.firstIndex(where: { $0.id == placeID }) {
                placeViewModels.remove(at: index)
            }
            
            // Remove from placeList.places
            placeList.places.removeAll { $0.id == placeID }
            
            // Remove from Firestore
            firestoreService.removePlaceFromList(userId: userId, listName: placeList.name, placeId: place.placeID!)
        } else {
            // Handle cases where placeID is nil
            print("Error: Cannot remove place. Invalid placeID.")
        }
    }

    func fetchFullPlaces(completion: @escaping ([GMSPlace]) -> Void) {
        let placesClient = GMSPlacesClient.shared()
        var fullPlaces: [GMSPlace] = []
        let dispatchGroup = DispatchGroup()

        for simplifiedPlace in placeList.places {
            dispatchGroup.enter()
            placesClient.lookUpPlaceID(simplifiedPlace.id) { place, error in
                if let place = place {
                    fullPlaces.append(place)
                } else if let error = error {
                    print("Error fetching place: \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(fullPlaces)
        }
    }

    func addPhotoToList(image: UIImage) {
        self.image = image // Set the image in the view model

        // Upload image to Firestore
        firestoreService.uploadImageAndUpdatePlaceList(userId: userId, placeList: placeList, image: image) { [weak self] error in
            if let error = error {
                print("Error adding photo to list: \(error.localizedDescription)")
                // Handle error (e.g., display an error message to the user)
            } else {
                print("Photo added to list successfully")
                self?.loadPlaceLists() // Reload the list to get the new image URL
            }
        }
    }
}

extension String {
    func toImage() -> UIImage? {
        if let data = Data(base64Encoded: self, options: .ignoreUnknownCharacters){
            return UIImage(data: data)
        }
        return nil
    }
}
