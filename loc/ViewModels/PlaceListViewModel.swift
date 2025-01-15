//
//  PlaceListViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import Foundation
import GooglePlaces

class PlaceListViewModel: ObservableObject,Identifiable {
    @Published var placeList: PlaceList
    private let firestoreService: FirestoreService
    private let userId: String
    
    @Published private var imageUpdateID = UUID()


    
    init(placeList: PlaceList, firestoreService: FirestoreService, userId: String) {
        self.placeList = placeList
        self.firestoreService = firestoreService
        self.userId = userId
        loadPlaceLists()
    }
    
    func loadPlaceLists() {
        firestoreService.fetchList(userId: userId, listName: placeList.name) { [weak self] result in
            switch result {
            case .success(let fetchedPlaceList):
                self?.placeList = fetchedPlaceList
            case .failure(let error):
                print("Failed to load place list: \(error.localizedDescription)")
            }
        }
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
        firestoreService.uploadImageAndUpdatePlaceList(userId: userId, placeList: placeList, image: image) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error adding photo to list: \(error.localizedDescription)")
                    // Handle error, possibly update UI to show an error message
                } else {
                    print("Photo added to list successfully")
                    // Update the imageUpdateID to trigger a re-render
                    self?.imageUpdateID = UUID()
                    // Optionally refresh the list or update the UI to reflect the change
                    self?.loadPlaceLists() // Reload the list to show the new image
                }
            }
        }
    }
}
