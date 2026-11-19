//
//  ListPlaceCategoryLoader.swift
//  loc
//
//  Attaches each list place's full raw categories and user-corrected category, which the list RPCs
//  omit (they return a single generalized place_type). One batched read of the `places` table per page.
//

import Foundation
import Supabase

enum ListPlaceCategoryLoader {
    /// Most ids sent in one `in` filter, keeping the request URL small.
    private static let chunkSize = 100

    private struct CategoryRow: Decodable {
        let id: String
        let categories: [String]?
        let user_corrected_category: String?
    }

    /// Returns the places with `categories` and `user_corrected_category` filled in. Best effort: on any
    /// failure the places come back unchanged and tags fall back to `place_type`.
    static func attachCategories(to places: [LightweightPlace], using client: SupabaseClient) async -> [LightweightPlace] {
        let ids = Array(Set(places.map { $0.place_id }))
        guard !ids.isEmpty else { return places }
        var rowsById: [String: CategoryRow] = [:]
        for start in stride(from: 0, to: ids.count, by: chunkSize) {
            let chunk = Array(ids[start..<min(start + chunkSize, ids.count)])
            guard let rows = await fetchRows(ids: chunk, using: client) else { continue }
            for row in rows { rowsById[row.id.lowercased()] = row }
        }
        return places.map { place in
            guard let row = rowsById[place.place_id.lowercased()] else { return place }
            return place.withCategories(row.categories, userCorrectedCategory: row.user_corrected_category)
        }
    }

    /// Reads the category columns for a chunk of place ids, or nil when the request fails.
    private static func fetchRows(ids: [String], using client: SupabaseClient) async -> [CategoryRow]? {
        do {
            let rows: [CategoryRow] = try await client
                .from("places")
                .select("id, categories, user_corrected_category")
                .in("id", values: ids)
                .execute()
                .value
            return rows
        } catch {
            print("⚠️ [ListPlaceCategoryLoader] Could not load categories: \(error)")
            return nil
        }
    }
}
