//
//  MapPlace.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/4/25.
//


import Foundation
import FirebaseFirestore

import FirebaseFirestore

struct MapPlace: Codable {
    var placeId: String
    var name: String
    var address: String?
    var addedBy: [String: MapPlaceUserInfo]  // Keyed by userId
}
