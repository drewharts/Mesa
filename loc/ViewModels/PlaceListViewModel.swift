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

class PlaceListViewModel: ObservableObject, Identifiable {
    @Published var placeList: PlaceList
    private let firestoreService: FirestoreService
    private let userId: String
    private var image: UIImage?

    init(placeList: PlaceList, firestoreService: FirestoreService, userId: String) {
        self.placeList = placeList
        self.firestoreService = firestoreService
        self.userId = userId
        loadPlaceLists()
    }
    
    func getImage() -> UIImage? {
        return image
    }

    func loadPlaceLists() {
        firestoreService.fetchList(userId: userId, listName: placeList.name) { [weak self] result in
            switch result {
            case .success(let fetchedPlaceList):
                self?.placeList = fetchedPlaceList

                // Fetch the image asynchronously if the URL is available
                if let imageURLString = fetchedPlaceList.image as? String,
                   let imageURL = URL(string: imageURLString) {
                    self?.fetchImage(from: imageURL)
                }

            case .failure(let error):
                print("Failed to load place list: \(error.localizedDescription)")
            }
        }
    }


    
    private func fetchImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.image = image
                }
            } else if let error = error {
                print("Failed to fetch image: \(error.localizedDescription)")
            }
        }.resume()
    }




    func addPlace(_ place: GMSPlace) {
        if let placeID = place.placeID {
            placeList.places.append(Place(id: placeID, name: place.name ?? "", address: place.formattedAddress ?? ""))
            firestoreService.addPlaceToList(userId: userId, listName: placeList.name, place: place)
        }
    }

    func removePlace(byID placeID: String) {
        placeList.places.removeAll { $0.id == placeID }
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
