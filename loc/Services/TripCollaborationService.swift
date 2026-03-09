//
//  TripCollaborationService.swift
//  loc
//
//  Service responsible for trip collaborator operations
//  Single Responsibility: CRUD operations for trip collaborators
//

import Foundation

/// Service for managing trip collaborators (fetch, add, remove, permissions)
@MainActor
class TripCollaborationService {
    // MARK: - Singleton
    static let shared = TripCollaborationService()

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Fetch Collaborators

    /// Fetches all collaborators for a trip with user details.
    func fetchCollaborators(tripId: String) async throws -> [LightweightCollaborator] {
        struct Row: Decodable {
            let id: String
            let userId: String
            let role: String
            let userName: String?
            let profilePhotoUrl: String?

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case role
                case userName = "user_name"
                case profilePhotoUrl = "profile_photo_url"
            }
        }

        let rows: [Row] = try await supabase.client
            .from("trip_collaborators")
            .select("id, user_id, role, users!trip_collaborators_user_id_fkey(full_name, profile_photo_url)")
            .eq("trip_id", value: tripId)
            .execute()
            .value

        // The join returns nested user data; decode manually
        // Fall back to a simpler query approach
        return try await fetchCollaboratorsViaRPC(tripId: tripId)
    }

    // MARK: - Add Collaborator

    /// Adds a user as a collaborator to a trip.
    func addCollaborator(
        tripId: String,
        userId: String,
        role: CollaboratorRole,
        addedBy: String
    ) async throws {
        let record = NewCollaboratorRecord(
            id: UUID().uuidString,
            trip_id: tripId,
            user_id: userId,
            role: role.rawValue,
            added_by: addedBy
        )

        try await supabase.client
            .from("trip_collaborators")
            .insert(record)
            .execute()
    }

    // MARK: - Remove Collaborator

    /// Removes a collaborator by their collaborator record ID.
    func removeCollaborator(collaboratorId: String) async throws {
        try await supabase.client
            .from("trip_collaborators")
            .delete()
            .eq("id", value: collaboratorId)
            .execute()
    }

    // MARK: - Permission Checks

    /// Checks if a user can edit a trip (is owner or editor collaborator).
    func canUserEditTrip(tripId: String, userId: String) async throws -> Bool {
        // Check ownership
        let ownerCheck: [OwnerCheckResult] = try await supabase.client
            .from("trips")
            .select("owner_id")
            .eq("id", value: tripId)
            .eq("owner_id", value: userId)
            .execute()
            .value

        if !ownerCheck.isEmpty { return true }

        // Check collaborator role
        let collabCheck: [RoleCheckResult] = try await supabase.client
            .from("trip_collaborators")
            .select("role")
            .eq("trip_id", value: tripId)
            .eq("user_id", value: userId)
            .eq("role", value: "editor")
            .execute()
            .value

        return !collabCheck.isEmpty
    }

    // MARK: - Private Helpers

    /// Fetches collaborators using a simple two-step approach (collaborator rows + user lookup).
    private func fetchCollaboratorsViaRPC(tripId: String) async throws -> [LightweightCollaborator] {
        struct CollabRow: Decodable {
            let id: String
            let user_id: String
            let role: String
        }

        let rows: [CollabRow] = try await supabase.client
            .from("trip_collaborators")
            .select("id, user_id, role")
            .eq("trip_id", value: tripId)
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        // Fetch user details for all collaborator user IDs
        let userIds = rows.map(\.user_id)

        struct UserRow: Decodable {
            let id: String
            let full_name: String?
            let profile_photo_url: String?
        }

        let users: [UserRow] = try await supabase.client
            .from("users")
            .select("id, full_name, profile_photo_url")
            .in("id", values: userIds)
            .execute()
            .value

        let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        return rows.map { row in
            let user = userMap[row.user_id]
            return LightweightCollaborator(
                id: row.id,
                userId: row.user_id,
                role: row.role,
                userName: user?.full_name,
                profilePhotoUrl: user?.profile_photo_url
            )
        }
    }
}

// MARK: - Private DTOs

private extension TripCollaborationService {
    struct NewCollaboratorRecord: Encodable {
        let id: String
        let trip_id: String
        let user_id: String
        let role: String
        let added_by: String
    }

    struct OwnerCheckResult: Decodable {
        let owner_id: String
    }

    struct RoleCheckResult: Decodable {
        let role: String
    }
}
