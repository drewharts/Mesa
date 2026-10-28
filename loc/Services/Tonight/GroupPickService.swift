//
//  GroupPickService.swift
//  loc
//
//  Creates, reads and votes on group picks via Supabase RPCs
//  (create_group_pick / get_group_pick / vote_group_pick, migration 20261026;
//  my_group_picks / invite_group_pick_members / add_group_pick_places, migration 20261027),
//  and builds the shareable universal link.
//

import Foundation
import Supabase

enum GroupPickError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "This group pick no longer exists."
        }
    }
}

@MainActor
final class GroupPickService {
    static let shared = GroupPickService()

    private let supabase = SupabaseManager.shared

    private init() {}

    /// Creates a group pick pre-filled with the given places and returns its id.
    func createPick(placeIds: [String], title: String, decideInMinutes: Int = 90) async throws -> String {
        let placeIds = placeIds.filter { !PlaceIdGuard.isPlaceholder($0) }
        struct Params: Encodable { let p_place_ids: [String]; let p_title: String; let p_minutes: Int }
        let id: String = try await supabase.client
            .rpc("create_group_pick", params: Params(p_place_ids: placeIds, p_title: title, p_minutes: decideInMinutes))
            .execute()
            .value
        return id
    }

    /// Loads a pick, joining the caller as a member and auto-deciding it if voting is done or time is up.
    func fetchPick(id: String) async throws -> GroupPick {
        struct Params: Encodable { let p_pick_id: String }
        let pick: GroupPick? = try await supabase.client
            .rpc("get_group_pick", params: Params(p_pick_id: id))
            .execute()
            .value
        guard let pick else { throw GroupPickError.notFound }
        return pick
    }

    /// Records the caller's yes/no on one place and returns the updated pick (which may now be decided).
    func vote(pickId: String, placeId: String, yes: Bool) async throws -> GroupPick {
        try PlaceIdGuard.requireReal(placeId)
        struct Params: Encodable { let p_pick_id: String; let p_place_id: String; let p_vote: Bool }
        let pick: GroupPick = try await supabase.client
            .rpc("vote_group_pick", params: Params(p_pick_id: pickId, p_place_id: placeId, p_vote: yes))
            .execute()
            .value
        return pick
    }

    /// The caller's active picks and picks decided in the last 24 hours (my_group_picks, 20261027 migration).
    /// Returns an empty list if the server doesn't have the function yet.
    func fetchMyPicks() async -> [GroupPickSummary] {
        struct NoParams: Encodable {}
        do {
            let picks: [GroupPickSummary] = try await supabase.client
                .rpc("my_group_picks", params: NoParams())
                .execute()
                .value
            return picks
        } catch {
            print("⚠️ [GroupPick] my_group_picks unavailable: \(error)")
            return []
        }
    }

    /// Adds friends to a pick (invite_group_pick_members) and returns the updated pick. They get a push.
    func invite(pickId: String, userIds: [String]) async throws -> GroupPick {
        struct Params: Encodable { let p_pick_id: String; let p_user_ids: [String] }
        let pick: GroupPick = try await supabase.client
            .rpc("invite_group_pick_members", params: Params(p_pick_id: pickId, p_user_ids: userIds))
            .execute()
            .value
        return pick
    }

    /// Adds places to the vote (add_group_pick_places). Reopens a pick that closed with no match.
    func addPlaces(pickId: String, placeIds: [String]) async throws -> GroupPick {
        struct Params: Encodable { let p_pick_id: String; let p_place_ids: [String] }
        let pick: GroupPick = try await supabase.client
            .rpc("add_group_pick_places", params: Params(p_pick_id: pickId, p_place_ids: placeIds))
            .execute()
            .value
        return pick
    }

    /// Returns the universal link for a pick: opens the app when installed, otherwise the App Store.
    func shareURL(pickId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = MesaBackendConfig.universalLinkHost
        components.path = "/pick/\(pickId.lowercased())"
        return components.url
    }
}
