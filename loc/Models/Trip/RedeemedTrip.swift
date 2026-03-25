//
//  RedeemedTrip.swift
//  loc
//
//  Response model for invitation redemption RPCs
//

import Foundation

/// Lightweight result from redeeming a trip invitation.
struct RedeemedTrip: Codable, Identifiable {
    let tripId: String
    let tripName: String

    var id: String { tripId }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case tripName = "trip_name"
    }
}
