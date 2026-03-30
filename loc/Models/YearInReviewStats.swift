//
//  YearInReviewStats.swift
//  loc
//
//  Summary stats for the user's Mesa activity recap.
//

import Foundation

struct YearInReviewStats: Codable {
    let placesReviewed: Int
    let placesFavorited: Int
    let listsCreated: Int
    let videosImported: Int
    let crownsReceived: Int
    let topCity: String?
    let citiesCount: Int

    enum CodingKeys: String, CodingKey {
        case placesReviewed = "places_reviewed"
        case placesFavorited = "places_favorited"
        case listsCreated = "lists_created"
        case videosImported = "videos_imported"
        case crownsReceived = "crowns_received"
        case topCity = "top_city"
        case citiesCount = "cities_count"
    }
}
