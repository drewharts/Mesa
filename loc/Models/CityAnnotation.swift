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
    let reviewCount: Int
    let friendCount: Int
    let reviewedPlaceCount: Int

    /// Uses the city name as a stable identifier.
    var id: String { name }

    /// Computed coordinate from latitude/longitude.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case latitude
        case longitude
        case placeCount = "place_count"
        case listCount = "list_count"
        case tiktokCount = "tiktok_count"
        case topPlaceTypes = "top_place_types"
        case reviewCount = "review_count"
        case friendCount = "friend_count"
        case reviewedPlaceCount = "reviewed_place_count"
    }
}

/// Lightweight place info returned from the get_city_top_places RPC.
struct CityTopPlace: Identifiable, Codable {
    let id: String
    let name: String
    let placeType: String
    let tiktokCount: Int
    let imageUrl: String?
    let latestReviewPhoto: String?
    let contentUrl: String?

    /// Returns an emoji representing the place type.
    var emoji: String {
        PlaceTypeEmoji.emoji(for: placeType)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case placeType = "place_type"
        case tiktokCount = "tiktok_count"
        case imageUrl = "image_url"
        case latestReviewPhoto = "latest_review_photo"
        case contentUrl = "tiktok_url"
    }
}

/// Lightweight city result from the search_cities RPC.
struct CitySearchResult: Identifiable, Codable {
    let cityName: String
    let latitude: Double
    let longitude: Double
    let placeCount: Int

    var id: String { cityName }

    /// Computed coordinate from latitude/longitude.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case cityName = "city_name"
        case latitude
        case longitude
        case placeCount = "place_count"
    }
}

/// User with saved places in a city, returned from the get_city_active_users RPC.
struct CityActiveUser: Identifiable, Codable, Hashable {
    let id: String
    let fullName: String
    let profilePhotoUrl: String?
    let placeCount: Int
    let listCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case profilePhotoUrl = "profile_photo_url"
        case placeCount = "place_count"
        case listCount = "list_count"
    }
}
