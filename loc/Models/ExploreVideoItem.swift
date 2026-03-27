//
//  ExploreVideoItem.swift
//  loc
//
//  Lightweight model for videos displayed in the Explore feed grid.
//

import Foundation

struct ExploreVideoItem: Identifiable, Codable {
    let externalPlaceId: String
    let url: String
    let source: String
    let placeId: String
    let placeName: String
    let userId: String
    let userFullName: String
    let userProfilePhotoUrl: String?
    let addedAt: String?

    var id: String { externalPlaceId }

    enum CodingKeys: String, CodingKey {
        case externalPlaceId = "external_place_id"
        case url
        case source
        case placeId = "place_id"
        case placeName = "place_name"
        case userId = "user_id"
        case userFullName = "user_full_name"
        case userProfilePhotoUrl = "user_profile_photo_url"
        case addedAt = "added_at"
    }
}
