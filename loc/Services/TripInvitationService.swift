//
//  TripInvitationService.swift
//  loc
//
//  Service for trip SMS invitation CRUD and redemption
//  Single Responsibility: Manage trip_invitations table operations
//

import Foundation

@MainActor
class TripInvitationService {

    // MARK: - Dependencies

    private let supabase = SupabaseManager.shared

    // MARK: - Constants

    private static let universalLinkHost = MesaBackendConfig.universalLinkHost

    // MARK: - Create Invitation

    /// Creates a trip invitation record and returns it (includes the generated token).
    func createInvitation(tripId: String, phone: String, invitedBy: String) async throws -> TripInvitation {
        let record = NewInvitationRecord(
            id: UUID().uuidString,
            trip_id: tripId,
            invited_phone: phone,
            invited_by: invitedBy
        )

        let result: TripInvitation = try await supabase.client
            .from("trip_invitations")
            .insert(record)
            .select()
            .single()
            .execute()
            .value

        return result
    }

    // MARK: - Fetch Pending

    /// Fetches all pending invitations for a given trip.
    func fetchPendingInvitations(tripId: String) async throws -> [TripInvitation] {
        let invitations: [TripInvitation] = try await supabase.client
            .from("trip_invitations")
            .select()
            .eq("trip_id", value: tripId)
            .eq("status", value: "pending")
            .execute()
            .value

        return invitations
    }

    // MARK: - Revoke

    /// Revokes a pending invitation by setting its status to 'revoked'.
    func revokeInvitation(invitationId: String) async throws {
        try await supabase.client
            .from("trip_invitations")
            .update(["status": "revoked"])
            .eq("id", value: invitationId)
            .execute()
    }

    // MARK: - Redeem by Phone

    /// Redeems all pending invitations matching a phone number (called post-signup).
    func redeemPendingInvitations(userId: String, phoneNumber: String) async throws -> [RedeemedTrip] {
        let result: [RedeemedTrip] = try await supabase.client
            .rpc("redeem_pending_invitations", params: [
                "p_user_id": userId,
                "p_phone_number": phoneNumber
            ])
            .execute()
            .value

        return result
    }

    // MARK: - Redeem by Token

    /// Redeems a specific invitation by its deep-link token.
    func redeemInvitationByToken(userId: String, token: String) async throws -> [RedeemedTrip] {
        let result: [RedeemedTrip] = try await supabase.client
            .rpc("redeem_invitation_by_token", params: [
                "p_user_id": userId,
                "p_token": token
            ])
            .execute()
            .value

        return result
    }

    // MARK: - URL Generation

    /// Generates a universal link URL for the invitation.
    func generateInviteURL(token: String, tripName: String, inviterName: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.universalLinkHost
        components.path = "/invite/\(token)"
        components.queryItems = [
            URLQueryItem(name: "tripName", value: tripName),
            URLQueryItem(name: "inviterName", value: inviterName)
        ]
        return components.url
    }
}

// MARK: - Private DTOs

private extension TripInvitationService {
    struct NewInvitationRecord: Encodable {
        let id: String
        let trip_id: String
        let invited_phone: String
        let invited_by: String
    }
}
