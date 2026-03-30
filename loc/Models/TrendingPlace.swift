//
//  TrendingPlace.swift
//  loc
//
//  Model for places ranked by crown count in the trending section.
//

import Foundation

struct TrendingPlace: Identifiable, Codable {
    let placeId: String
    let placeName: String
    let city: String?
    let placeType: String?
    let crownCount: Int
    let photoUrl: String?

    var id: String { placeId }

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case placeName = "place_name"
        case city
        case placeType = "place_type"
        case crownCount = "crown_count"
        case photoUrl = "photo_url"
    }
}
