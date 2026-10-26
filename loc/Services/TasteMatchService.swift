//
//  TasteMatchService.swift
//  loc
//
//  Taste match % between the signed-in user and another user.
//  Computed entirely in Postgres (RPC get_taste_match, scoped to auth.uid()),
//  so there are no AI/API costs. Results are cached in memory per session.
//

import Foundation
import Supabase

struct TasteMatch: Codable, Equatable {
    let score: Int?
    let enoughData: Bool
    let sharedPlaces: Int
    let topSharedCategory: String?

    enum CodingKeys: String, CodingKey {
        case score
        case enoughData = "enough_data"
        case sharedPlaces = "shared_places"
        case topSharedCategory = "top_shared_category"
    }

    /// Human-readable shared category, e.g. "wine_bar" -> "wine bars".
    var sharedCategoryLabel: String? {
        guard let raw = topSharedCategory, !raw.isEmpty else { return nil }
        let words = raw.replacingOccurrences(of: "_", with: " ")
        return words.hasSuffix("s") ? words : words + "s"
    }
}

@MainActor
final class TasteMatchService {
    static let shared = TasteMatchService()
    private var cache: [String: (TasteMatch, Date)] = [:]
    private let ttl: TimeInterval = 10 * 60

    func fetchTasteMatch(otherUserId: String) async -> TasteMatch? {
        if let (match, at) = cache[otherUserId], Date().timeIntervalSince(at) < ttl {
            return match
        }
        do {
            let rows: [TasteMatch] = try await SupabaseManager.shared.client
                .rpc("get_taste_match", params: ["p_other_user_id": otherUserId])
                .execute()
                .value
            guard let match = rows.first else { return nil }
            cache[otherUserId] = (match, Date())
            return match
        } catch {
            // Non-fatal: hide the badge (e.g. function not deployed yet).
            print("TasteMatchService error: \(error)")
            return nil
        }
    }

    func invalidate() { cache.removeAll() }
}
