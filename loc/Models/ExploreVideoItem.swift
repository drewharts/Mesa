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
    let placeType: String?
    let city: String?
    let addedAt: String?
    let thumbnailUrl: String?
    let placePhotoUrl: String?

    var id: String { externalPlaceId }

    /// Formatted subtitle combining place type and city (e.g. "Korean · Mexico City").
    var subtitle: String {
        [placeType, city].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case externalPlaceId = "external_place_id"
        case url
        case source
        case placeId = "place_id"
        case placeName = "place_name"
        case placeType = "place_type"
        case city
        case addedAt = "added_at"
        case thumbnailUrl = "thumbnail_url"
        case placePhotoUrl = "place_photo_url"
    }
}
