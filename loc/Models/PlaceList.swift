//
//  PlaceList.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation

struct PlaceList: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var places: [Place] = []
    var city: String
    var emoji: String
    var image: String?
}

