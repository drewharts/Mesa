//
//  ExternalAssociatedPlace.swift
//  loc
//
//  Model representing a place associated with an external video.
//

import Foundation

struct ExternalAssociatedPlace: Identifiable, Codable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case id = "place_id"
        case name = "place_name"
        case address = "place_address"
        case latitude
        case longitude
    }
}
