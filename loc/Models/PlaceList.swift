//
//  PlaceList.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import GooglePlaces

struct SimplifiedPlace: Codable {
    let placeID: String
    let name: String
    let address: String
}

class PlaceList: Codable, Identifiable, ObservableObject {
//    let id = UUID()
    var name: String
    var places: [SimplifiedPlace] = []
    
    init(name: String) {
        self.name = name
    }
    
    func addPlace(_ place: GMSPlace) {
        if let placeID = place.placeID {
            places.append(SimplifiedPlace(placeID: placeID, name: place.name ?? "", address: place.formattedAddress ?? ""))
        }
    }
    
    func removePlace(byID placeID: String) {
        places.removeAll { $0.placeID == placeID }
    }
    
    func fetchFullPlaces(completion: @escaping ([GMSPlace]) -> Void) {
        let placesClient = GMSPlacesClient.shared()
        var fullPlaces: [GMSPlace] = []
        let dispatchGroup = DispatchGroup()
        
        for simplifiedPlace in places {
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
