//
//  ExploreListsService.swift
//  loc
//
//  Reads public lists straight from `place_lists` (readable by RLS) for the Explore tab.
//  No RPCs or migrations: counts come from the embedded `place_list_items(count)`.
//

import Foundation
import CoreLocation
import Supabase

@MainActor
final class ExploreListsService {
    static let shared = ExploreListsService()

    private let supabase = SupabaseManager.shared
    private nonisolated init() {}

    private static let columns = "id, name, image, city, created_at, updated_at, user_id, average_location::text, place_list_items(count)"

    private struct CountRow: Decodable {
        let count: Int
    }

    private struct ListRow: Decodable {
        let id: String
        let name: String
        let image: String?
        let city: String?
        let created_at: String?
        let updated_at: String?
        let user_id: String
        let average_location: String?
        let place_list_items: [CountRow]?
    }

    private struct OwnerRow: Decodable {
        let id: String
        let full_name: String?
        let profile_photo_url: String?
    }

    // MARK: - Lists

    /// Fetches the most recently updated public lists that have at least one place.
    func fetchRecentPublicLists(limit: Int) async throws -> [ExploreList] {
        let rows: [ListRow] = try await supabase.client
            .from("place_lists")
            .select(Self.columns)
            .eq("is_public", value: true)
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap(Self.makeList)
    }

    /// Fetches public lists tagged with any of the given raw city names.
    func fetchPublicLists(inCities cityNames: [String], limit: Int) async throws -> [ExploreList] {
        let rows: [ListRow] = try await supabase.client
            .from("place_lists")
            .select(Self.columns)
            .eq("is_public", value: true)
            .in("city", values: cityNames)
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap(Self.makeList)
    }

    // MARK: - Owners

    /// Fetches display names and photos for the given owner ids in one query; failures yield an empty map.
    func fetchOwners(ids: [String]) async -> [String: ExploreListOwner] {
        guard !ids.isEmpty else { return [:] }
        do {
            let rows: [OwnerRow] = try await supabase.client
                .from("users")
                .select("id, full_name, profile_photo_url")
                .in("id", values: ids)
                .execute()
                .value
            return Dictionary(rows.map { row in
                (row.id, ExploreListOwner(name: row.full_name ?? "", photoURL: row.profile_photo_url))
            }, uniquingKeysWith: { first, _ in first })
        } catch {
            print("⚠️ [ExploreListsService] Owner lookup failed: \(error)")
            return [:]
        }
    }

    /// Returns the ids of users the given user follows; failures yield an empty set.
    func fetchFollowedUserIds(userId: String) async -> Set<String> {
        do {
            return Set(try await SupabaseUserService.shared.fetchFollowingUserIds(userId: userId))
        } catch {
            print("⚠️ [ExploreListsService] Following lookup failed: \(error)")
            return []
        }
    }

    // MARK: - Mapping

    /// Maps a database row to an ExploreList, dropping empty lists.
    private static func makeList(_ row: ListRow) -> ExploreList? {
        let placeCount = row.place_list_items?.first?.count ?? 0
        guard placeCount > 0 else { return nil }
        let coordinate = LightweightPlaceList(
            list_id: row.id, name: row.name, is_public: true, image: nil,
            created_at: nil, updated_at: nil, distance_meters: nil,
            place_count: placeCount, city: row.city, average_location_raw: row.average_location
        ).averageLocation
        return ExploreList(
            id: row.id,
            name: row.name,
            city: row.city,
            imageURL: row.image,
            ownerId: row.user_id,
            placeCount: placeCount,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        )
    }
}
