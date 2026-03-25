//
//  TripTravelTimeSegment.swift
//  loc
//
//  Travel time data for one segment between consecutive trip places
//

import Foundation

/// Represents travel time data between two consecutive places in a trip day itinerary.
struct TripTravelTimeSegment: Equatable {
    let fromPlaceId: String
    let toPlaceId: String
    var travelTimes: [MapKitService.TransportType: TimeInterval]
    var isLoading: Bool
    var hasFailed: Bool

    /// Cache key for dictionary storage, directional because routes differ by direction.
    var cacheKey: String { "\(fromPlaceId)->\(toPlaceId)" }
}
