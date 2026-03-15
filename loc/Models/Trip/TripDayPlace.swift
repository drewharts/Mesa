//
//  TripDayPlace.swift
//  loc
//
//  Place assigned to a specific day in a trip itinerary
//

import Foundation

/// Represents a place on a specific day of a trip, with joined place and user info.
struct TripDayPlace: Codable, Identifiable, Equatable {
    let id: String
    let tripId: String
    let placeId: String
    var dayIndex: Int
    var sortOrder: Int
    let addedBy: String?
    var note: String?

    // Joined place fields (from get_trip_with_places RPC)
    let placeName: String?
    let placeAddress: String?
    let placeLatitude: Double?
    let placeLongitude: Double?
    let placePhoto: String?

    // Joined user fields
    let addedByName: String?
    let addedByPhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "day_place_id"
        case tripId = "trip_id"
        case placeId = "place_id"
        case dayIndex = "day_index"
        case sortOrder = "sort_order"
        case addedBy = "added_by"
        case note
        case placeName = "place_name"
        case placeAddress = "place_address"
        case placeLatitude = "place_latitude"
        case placeLongitude = "place_longitude"
        case placePhoto = "place_photo"
        case addedByName = "added_by_name"
        case addedByPhotoUrl = "added_by_photo_url"
    }
}
