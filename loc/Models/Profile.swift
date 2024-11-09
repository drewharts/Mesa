//
//  Profile.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation

class Profile {
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var placeLists: [PlaceList] = []
    
    init(firstName: String, lastName: String, phoneNumber: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
    }
    
    func addPlacesList(_ placeList: PlaceList) {
        placeLists.append(placeList)
    }
    
    func removePlacesList(named name: String) {
        placeLists.removeAll { $0.name == name }
    }
    
}
