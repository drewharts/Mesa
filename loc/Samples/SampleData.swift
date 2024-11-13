
//
//  SampleData.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import GooglePlaces
import SwiftUI

struct SampleData {
    static var exampleProfile: Profile {
        let profile = Profile(firstName: "Jane", lastName: "Doe", phoneNumber: "555-1234")
        
        let placeList1 = PlaceList(name: "Favorite Spots")
        let placeList2 = PlaceList(name: "Visited Recently")
        
        // Add some example places to the place lists
        let mockPlace1 = GMSPlace() // Replace with actual GMSPlace data in a live app
        let mockPlace2 = GMSPlace()

        placeList1.places.append(contentsOf: [mockPlace1, mockPlace2])
        placeList2.places.append(mockPlace1)

        profile.addPlacesList(placeList1)
        profile.addPlacesList(placeList2)
        
        return profile
    }
}
