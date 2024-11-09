//
//  PlaceList.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import GooglePlaces

class PlaceList {
    var name: String
    var places: [GMSPlace] = []
    
    init(name: String) {
        self.name = name
    }
    
    func addPlace(_ place: GMSPlace) {
        places.append(place)
    }
    
    func removePlace(byID placeID: String) {
        places.removeAll { $0.placeID == placeID }
    }

}
