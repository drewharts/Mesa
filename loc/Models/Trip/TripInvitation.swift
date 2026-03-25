//
//  TripInvitation.swift
//  loc
//
//  Model for SMS trip invitations sent to non-users
//

import Foundation

/// Represents a pending SMS invitation for a non-user to join a trip.
struct TripInvitation: Codable, Identifiable, Equatable {
    let id: String
    let tripId: String
    let token: String
    let invitedPhone: String
    let invitedBy: String
    let role: String
    let status: String
    let createdAt: String?
    let expiresAt: String?

    var isPending: Bool { status == "pending" }

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case token
        case invitedPhone = "invited_phone"
        case invitedBy = "invited_by"
        case role
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}
