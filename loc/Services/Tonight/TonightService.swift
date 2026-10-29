//
//  TonightService.swift
//  loc
//
//  Gathers Tonight candidates (places saved by the user and the people they
//  follow) using only data already in Supabase: no Google Places calls.
//  Prefers the get_tonight_candidates RPC (sees friends' favorites and TikTok
//  saves); if it is not deployed yet, falls back to the user's own saves plus
//  friends' public lists, which the client can already read.
//

import Foundation
import CoreLocation
import Supabase

@MainActor
final class TonightService {
    static let shared = TonightService()

    /// Max places whose full details are fetched per Tonight load.
    static let detailFetchLimit = 150 // Supabase only (no Google); enough for Coffee to find 3

    private let supabase = SupabaseManager.shared
    private let placeService = SupabasePlaceService.shared
    private var friendCache: (userId: String, friends: [TonightFriend], at: Date)?
    private let cacheTTL: TimeInterval = 10 * 60

    private init() {}

    // MARK: - Friends

    /// Returns the people the user follows, with first names, cached for 10 minutes.
    func fetchFriends(userId: String) async -> [TonightFriend] {
        if let cache = friendCache, cache.userId == userId, Date().timeIntervalSince(cache.at) < cacheTTL {
            return cache.friends
        }
        struct FollowRow: Decodable { let following_id: String }
        struct UserRow: Decodable { let id: String; let first_name: String? }
        do {
            let follows: [FollowRow] = try await supabase.client
                .from("following")
                .select("following_id")
                .eq("follower_id", value: userId)
                .limit(500)
                .execute()
                .value
            let ids = Array(Set(follows.map { $0.following_id }))
            var friends: [TonightFriend] = []
            for chunk in ids.chunked(into: 150) {
                let users: [UserRow] = try await supabase.client
                    .from("users")
                    .select("id, first_name")
                    .in("id", values: chunk)
                    .execute()
                    .value
                friends += users.map { TonightFriend(id: $0.id, firstName: $0.first_name ?? "") }
            }
            friendCache = (userId, friends, Date())
            return friends
        } catch {
            print("⚠️ [TonightService] Could not load friends: \(error)")
            return []
        }
    }

    // MARK: - Candidates

    /// Returns every place saved by the user or the given friends, with who saved it.
    func fetchCandidates(userId: String, friendIds: [String]) async -> [TonightCandidate] {
        if let viaRPC = try? await fetchCandidatesViaRPC(friendIds: friendIds), !viaRPC.isEmpty {
            return viaRPC
        }
        return await fetchCandidatesFallback(userId: userId, friendIds: friendIds)
    }

    /// Calls get_tonight_candidates (requires the 20261026 migration).
    private func fetchCandidatesViaRPC(friendIds: [String]) async throws -> [TonightCandidate] {
        struct Params: Encodable { let p_user_ids: [String] }
        struct Row: Decodable { let place_id: String; let saver_ids: [String]? }
        // PostgREST caps every response at 1000 rows (max_rows), so an unpaged call silently
        // dropped an arbitrary slice of saves once user + friends passed 1000 places. Page through
        // with a stable order until a short page comes back.
        let pageSize = 1000
        var rows: [Row] = []
        var offset = 0
        while offset < 20_000 {
            let page: [Row] = try await supabase.client
                .rpc("get_tonight_candidates", params: Params(p_user_ids: friendIds))
                .order("place_id")
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            rows += page
            if page.count < pageSize { break }
            offset += pageSize
        }
        return rows.map { TonightCandidate(placeId: $0.place_id, saverIds: Set(($0.saver_ids ?? []).map { $0.lowercased() })) }
    }

    /// Builds candidates from tables the client can read today: own saves and friends' public lists.
    private func fetchCandidatesFallback(userId: String, friendIds: [String]) async -> [TonightCandidate] {
        struct SaveRow: Decodable { let place_id: String? }
        struct ListRow: Decodable { let id: String; let user_id: String; let is_public: Bool? }
        struct ItemRow: Decodable { let list_id: String; let place_id: String? }

        var savers: [String: Set<String>] = [:]
        let me = userId.lowercased()

        func add(_ placeId: String?, _ saver: String) {
            guard let placeId, !placeId.isEmpty else { return }
            savers[placeId, default: []].insert(saver.lowercased())
        }

        for table in ["favorites", "my_places", "external_places"] {
            do {
                let rows: [SaveRow] = try await supabase.client
                    .from(table)
                    .select("place_id")
                    .eq("user_id", value: userId)
                    .limit(2000)
                    .execute()
                    .value
                rows.forEach { add($0.place_id, me) }
            } catch {
                print("⚠️ [TonightService] \(table) read failed: \(error)")
            }
        }

        do {
            var lists: [ListRow] = []
            for chunk in ([userId] + friendIds).chunked(into: 150) {
                let rows: [ListRow] = try await supabase.client
                    .from("place_lists")
                    .select("id, user_id, is_public")
                    .in("user_id", values: chunk)
                    .execute()
                    .value
                lists += rows
            }
            let visible = lists.filter { $0.user_id.lowercased() == me || $0.is_public != false }
            let ownerByList = Dictionary(visible.map { ($0.id, $0.user_id) }, uniquingKeysWith: { a, _ in a })
            for chunk in Array(ownerByList.keys).chunked(into: 150) {
                let items: [ItemRow] = try await supabase.client
                    .from("place_list_items")
                    .select("list_id, place_id")
                    .in("list_id", values: chunk)
                    .execute()
                    .value
                for item in items {
                    if let owner = ownerByList[item.list_id] { add(item.place_id, owner) }
                }
            }
        } catch {
            print("⚠️ [TonightService] list read failed: \(error)")
        }

        return savers.map { TonightCandidate(placeId: $0.key, saverIds: $0.value) }
    }

    // MARK: - Places

    /// Fetches full details for the candidates nearest the origin (or most-saved when there is no origin).
    /// Returns details keyed by lowercased place id.
    func fetchDetails(for candidates: [TonightCandidate], near origin: CLLocation?) async -> [String: DetailPlace] {
        guard !candidates.isEmpty else { return [:] }
        let chosenIds: [String]
        if let origin {
            var coordinates: [String: CLLocationCoordinate2D] = [:]
            for chunk in candidates.map(\.placeId).chunked(into: 150) {
                if let batch = try? await placeService.fetchPlaceCoordinates(placeIds: chunk) {
                    coordinates.merge(batch) { a, _ in a }
                }
            }
            chosenIds = coordinates
                .map { (id: $0.key, meters: origin.distance(from: CLLocation(latitude: $0.value.latitude, longitude: $0.value.longitude))) }
                .filter { $0.meters <= TonightRanker.maxDistanceMeters }
                .sorted { $0.meters < $1.meters }
                .prefix(Self.detailFetchLimit)
                .map { $0.id }
        } else {
            chosenIds = candidates
                .sorted { $0.saverIds.count > $1.saverIds.count }
                .prefix(Self.detailFetchLimit)
                .map(\.placeId)
        }
        guard !chosenIds.isEmpty else { return [:] }

        var details: [String: DetailPlace] = [:]
        for chunk in chosenIds.chunked(into: 30) {
            guard let places = try? await placeService.fetchPlaceDetailsBatch(placeIds: chunk) else { continue }
            for place in places {
                details[place.id.uuidString.lowercased()] = place
            }
        }
        return details
    }

    /// Fetches details for an explicit list of place ids (used by group picks), keyed by lowercased id.
    func fetchDetails(placeIds: [String]) async -> [String: DetailPlace] {
        guard !placeIds.isEmpty,
              let places = try? await placeService.fetchPlaceDetailsBatch(placeIds: placeIds) else { return [:] }
        return Dictionary(places.map { ($0.id.uuidString.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
    }
}
