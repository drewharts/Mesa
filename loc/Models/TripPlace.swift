//
//  TripPlace.swift
//  loc
//
//  Model representing a place assigned to a specific day within a trip.
//

import Foundation

/// Represents a place assigned to a specific day in a trip.
struct TripPlace: Identifiable, Codable {
    let id: UUID
    let tripId: UUID
    let placeId: String
    let dayDate: Date
    var sortOrder: Int
    var notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case placeId = "place_id"
        case dayDate = "day_date"
        case sortOrder = "sort_order"
        case notes
        case createdAt = "created_at"
    }

    /// Creates a new trip place assignment.
    init(
        id: UUID = UUID(),
        tripId: UUID,
        placeId: String,
        dayDate: Date,
        sortOrder: Int = 0,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.placeId = placeId
        self.dayDate = dayDate
        self.sortOrder = sortOrder
        self.notes = notes
        self.createdAt = createdAt
    }
}
