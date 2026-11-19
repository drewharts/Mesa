//
//  ListTagSourceLoader.swift
//  loc
//
//  Fetches the small per-place data the tag chips need (id, name, categories, user-corrected category) for
//  EVERY place in a list in one embedded read of `place_list_items` -> `places`, with no photos or descriptions.
//

import Foundation
import Supabase

enum ListTagSourceLoader {
    /// Rows requested per round trip (PostgREST caps a response at 1000 rows by default).
    private static let rangeSize = 1000

    private struct Row: Decodable {
        struct PlaceFields: Decodable {
            let name: String?
            let categories: [String]?
            let user_corrected_category: String?
        }
        let place_id: String
        let places: PlaceFields?
    }

    /// Returns a tag-only LightweightPlace for each place in the list, or nil when the request fails.
    static func fetch(listId: String, using client: SupabaseClient) async -> [LightweightPlace]? {
        var result: [LightweightPlace] = []
        var start = 0
        while true {
            do {
                let rows: [Row] = try await client
                    .from("place_list_items")
                    .select("place_id, places(name, categories, user_corrected_category)")
                    .eq("list_id", value: listId)
                    .order("place_id")
                    .range(from: start, to: start + rangeSize - 1)
                    .execute()
                    .value
                result += rows.map(place(from:))
                if rows.count < rangeSize { return result }
                start += rangeSize
            } catch {
                print("⚠️ [ListTagSourceLoader] Could not load tag source: \(error)")
                return nil
            }
        }
    }

    /// Maps one joined row to a tag-only place.
    private static func place(from row: Row) -> LightweightPlace {
        LightweightPlace(
            place_id: row.place_id,
            name: row.places?.name ?? "",
            latest_review_photo: nil,
            categories: row.places?.categories,
            user_corrected_category: row.places?.user_corrected_category
        )
    }
}
