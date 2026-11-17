//
//  SavedLibraryDataSource.swift
//  loc
//
//  Read-only queries behind the Saved library: every place the user has (lists, favorites,
//  my places, imports) and which places each list holds. Writes nothing.
//

import Foundation
import Supabase

enum SavedLibraryDataSource {
    /// Reads list / favorite / my-place places, imports, and one-tap saves (favorites rows, which carry
    /// a timestamp) and returns one input per row (dupes are merged later by SavedLibraryBuilder).
    static func fetchInputs(userId: String) async throws -> [SavedPlaceInput] {
        async let saved = PlaceService.shared.fetchAllUserPlaces(userId: userId)
        async let imports = fetchRows(table: "external_places", timeColumn: "added_at", userId: userId)
        async let quickSaves = fetchRows(table: "favorites", timeColumn: "timestamp", userId: userId)
        let savedPlaces = try await saved
        let importRows = (try? await imports) ?? []
        let quickSaveRows = (try? await quickSaves) ?? []

        var inputs = savedPlaces.map { input(from: $0, source: .list, addedAt: nil) }
        let known = await resolvePlaces(savedPlaces, rows: importRows + quickSaveRows)
        for row in importRows {
            guard let place = known[row.placeId] else { continue }
            inputs.append(input(from: place, source: .imported, addedAt: row.addedAt))
        }
        for row in quickSaveRows {
            guard let place = known[row.placeId] else { continue }
            inputs.append(input(from: place, source: .saved, addedAt: row.addedAt))
        }
        return inputs
    }

    /// Returns the ids (lowercased) of the places in each of the given lists, keyed by lowercased list id.
    /// Throws when any page fails, so callers never mistake a partial read for an empty list.
    static func fetchListMemberships(listIds: [String]) async throws -> [String: Set<String>] {
        struct Row: Decodable { let list_id: String; let place_id: String }
        var result: [String: Set<String>] = [:]
        let unique = Array(Set(listIds))
        for chunk in stride(from: 0, to: unique.count, by: 50).map({ Array(unique[$0..<min($0 + 50, unique.count)]) }) {
            let variants = Array(Set(chunk + chunk.map { $0.lowercased() } + chunk.map { $0.uppercased() }))
            var offset = 0
            while offset < 20_000 {
                let page: [Row] = try await SupabaseManager.shared.client
                    .from("place_list_items")
                    .select("list_id, place_id")
                    .in("list_id", values: variants)
                    .order("list_id")
                    .order("place_id")
                    .range(from: offset, to: offset + 999)
                    .execute()
                    .value
                for row in page { result[row.list_id.lowercased(), default: []].insert(row.place_id.lowercased()) }
                if page.count < 1000 { break }
                offset += 1000
            }
        }
        return result
    }

    // MARK: - Private

    private struct TimedRow { let placeId: String; let addedAt: Date? }

    /// Reuses already-loaded places and batch-fetches the ones only import / save rows mention.
    private static func resolvePlaces(_ loaded: [DetailPlace], rows: [TimedRow]) async -> [String: DetailPlace] {
        var known: [String: DetailPlace] = [:]
        for p in loaded { known[p.id.uuidString.lowercased()] = p }
        let missing = Array(Set(rows.map(\.placeId).filter { known[$0] == nil }))
        for chunk in stride(from: 0, to: missing.count, by: 50).map({ Array(missing[$0..<min($0 + 50, missing.count)]) }) {
            // place ids are stored uppercase; ask for both spellings.
            let ids = chunk + chunk.map { $0.uppercased() }
            if let places = try? await PlaceService.shared.fetchPlaceDetailsBatch(placeIds: ids) {
                for p in places { known[p.id.uuidString.lowercased()] = p }
            }
        }
        return known
    }

    /// The user's rows in `table` (place id + when added), newest first, paged past Supabase's 1,000-row cap.
    private static func fetchRows(table: String, timeColumn: String, userId: String) async throws -> [TimedRow] {
        struct Raw: Decodable {
            let place_id: String?
            let time: String?
            enum CodingKeys: String, CodingKey { case place_id, time }
        }
        let userIds = Array(Set([userId, userId.uppercased(), userId.lowercased()]))
        var rows: [TimedRow] = []
        let pageSize = 1000
        var offset = 0
        while offset < 10_000 {
            // "time:<column>" aliases the timestamp column so one decoder fits both tables.
            let page: [Raw] = try await SupabaseManager.shared.client
                .from(table)
                .select("place_id, time:\(timeColumn)")
                .in("user_id", values: userIds)
                .order(timeColumn, ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            rows += page.compactMap { raw in
                raw.place_id.map { TimedRow(placeId: $0.lowercased(), addedAt: SavedLibraryBuilder.parseTimestamp(raw.time)) }
            }
            if page.count < pageSize { break }
            offset += pageSize
        }
        return rows
    }

    /// Flattens a DetailPlace into the Foundation-only input the builder sorts.
    private static func input(from place: DetailPlace, source: SavedPlaceInput.Source, addedAt: Date?) -> SavedPlaceInput {
        SavedPlaceInput(
            id: place.id.uuidString,
            name: place.name,
            address: place.address,
            storedCity: place.city,
            latitude: place.coordinate?.latitude,
            longitude: place.coordinate?.longitude,
            categories: place.categories ?? [],
            userCorrectedCategory: place.userCorrectedCategory,
            googlePlaceId: place.googlePlaceId,
            isDinnerSpot: TonightCategoryClassifier.fit(place, vibe: .dinner) > 0,
            addedAt: addedAt,
            sources: [source]
        )
    }
}
