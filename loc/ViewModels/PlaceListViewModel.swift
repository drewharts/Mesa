//
//  PlaceListViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import Foundation
import GooglePlaces

class PlaceListViewModel: ObservableObject {
    @Published var placeList: PlaceList
    private let firestoreService: FirestoreService
    private let userId: String

    
    init(placeList: PlaceList, firestoreService: FirestoreService, userId: String) {
        self.placeList = placeList
        self.firestoreService = firestoreService
        self.userId = userId
    }
    
    func addPlace(_ place: GMSPlace) {
        if let placeID = place.placeID {
            placeList.places.append(Place(placeID: placeID, name: place.name ?? "", address: place.formattedAddress ?? ""))
            firestoreService.addPlaceToList(userId: userId, listName: placeList.name, place: place)
        }
    }
    
    func removePlace(byID placeID: String) {
        placeList.places.removeAll { $0.placeID == placeID }
    }
    
    func fetchFullPlaces(completion: @escaping ([GMSPlace]) -> Void) {
        let placesClient = GMSPlacesClient.shared()
        var fullPlaces: [GMSPlace] = []
        let dispatchGroup = DispatchGroup()
        
        for simplifiedPlace in placeList.places {
            dispatchGroup.enter()
            placesClient.lookUpPlaceID(simplifiedPlace.placeID) { place, error in
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
}
