//
//  GroupPickService.swift
//  loc
//
//  Creates, reads and votes on group picks via Supabase RPCs
//  (create_group_pick / get_group_pick / vote_group_pick, migration 20261026),
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

    /// Returns the universal link for a pick: opens the app when installed, otherwise the App Store.
    func shareURL(pickId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = MesaBackendConfig.universalLinkHost
        components.path = "/pick/\(pickId.lowercased())"
        return components.url
    }
}
