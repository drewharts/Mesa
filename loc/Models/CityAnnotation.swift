//
//  CityAnnotation.swift
//  loc
//
//  City-level map annotation aggregating saved places by city.
//  Displayed when the user zooms out past the city threshold.
//

import Foundation
import CoreLocation

/// Aggregated city annotation returned from the get_city_annotations_in_viewport RPC.
struct CityAnnotation: Identifiable, Codable, Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let placeCount: Int
    let listCount: Int
    let tiktokCount: Int
    let topPlaceTypes: [String]

    /// Uses the city name as a stable identifier.
    var id: String { name }

    /// Computed coordinate from latitude/longitude.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Returns emojis for the top place types.
    var topEmojis: [String] {
        topPlaceTypes.prefix(3).map { PlaceTypeEmoji.emoji(for: $0) }
    }

    /// Formatted summary string for the annotation marker.
    var summary: String {
        var parts: [String] = []
        parts.append("\(placeCount) place\(placeCount == 1 ? "" : "s")")
        if tiktokCount > 0 {
            parts.append("\(tiktokCount) TikTok\(tiktokCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case name
        case latitude
        case longitude
        case placeCount = "place_count"
        case listCount = "list_count"
        case tiktokCount = "tiktok_count"
        case topPlaceTypes = "top_place_types"
    }
}

/// Lightweight place info returned from the get_city_top_places RPC.
struct CityTopPlace: Identifiable, Codable {
    let id: String
    let name: String
    let placeType: String
    let tiktokCount: Int

    /// Returns an emoji representing the place type.
    var emoji: String {
        PlaceTypeEmoji.emoji(for: placeType)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case placeType = "place_type"
        case tiktokCount = "tiktok_count"
    }
}
