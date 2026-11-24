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
import os

@MainActor
final class ExploreListsService {
    static let shared = ExploreListsService()

    private let supabase = SupabaseManager.shared
    private var coverPhotoCache: [String: [String]] = [:]
    private let coverChunkSize = 20
    /// Place rows embedded per list; extra candidates let a collage replace photos that fail to load.
    private let coversPerList = 8
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

    private struct CoverPlaceRow: Decodable {
        let thumbnail_url: String?
        let photo_urls: [String]?
    }

    private struct CoverItemRow: Decodable {
        let places: CoverPlaceRow?
    }

    private struct CoverListRow: Decodable {
        let id: String
        let place_list_items: [CoverItemRow]?
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

    /// Fetches specific lists by id (used for featured lists); missing or empty lists are omitted.
    func fetchLists(ids: [String]) async -> [ExploreList] {
        guard !ids.isEmpty else { return [] }
        do {
            let rows: [ListRow] = try await supabase.client
                .from("place_lists")
                .select(Self.columns)
                .in("id", values: ids)
                .execute()
                .value
            return rows.compactMap(Self.makeList)
        } catch {
            print("⚠️ [ExploreListsService] Featured lists lookup failed: \(error)")
            return []
        }
    }

    // MARK: - Cover Photos

    /// Returns the cover photos saved by the previous session (may be stale; revalidated by `fetchCoverPhotos`).
    func persistedSnapshot() -> CoverPhotoSnapshot {
        CoverPhotoStore.shared.load()
    }

    /// Saves this session's cover map together with the order lists appear on screen, for the next launch.
    func persistCovers(displayOrder: [String]) {
        var snapshot = CoverPhotoStore.shared.load()
        snapshot.covers.merge(coverPhotoCache) { _, fresh in fresh }
        snapshot.displayOrder = displayOrder
        CoverPhotoStore.shared.save(snapshot)
    }

    /// Returns up to `coversPerList` place photo URLs per list (in list order), fetching lists in a few parallel
    /// chunks of one embedded query each and caching results for the session. Failed chunks are omitted.
    func fetchCoverPhotos(listIds: [String]) async -> [String: [String]] {
        let missing = Array(Set(listIds).filter { coverPhotoCache[$0] == nil })
        let signpostId = ImagePerf.signposter.makeSignpostID()
        let state = ImagePerf.signposter.beginInterval("coverFetch", id: signpostId)
        let started = Date()
        let chunks = stride(from: 0, to: missing.count, by: coverChunkSize).map {
            Array(missing[$0..<min($0 + coverChunkSize, missing.count)])
        }
        await withTaskGroup(of: [String: [String]]?.self) { group in
            for chunk in chunks {
                group.addTask { await self.fetchCoverChunk(chunk) }
            }
            for await result in group {
                if let result { coverPhotoCache.merge(result) { _, new in new } }
            }
        }
        ImagePerf.signposter.endInterval("coverFetch", state)
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
        ImagePerf.logger.info("coverFetch requested=\(listIds.count) fetched=\(missing.count) chunks=\(chunks.count) ms=\(elapsed)")
        return listIds.reduce(into: [:]) { acc, id in
            if let photos = coverPhotoCache[id] { acc[id] = photos }
        }
    }

    /// Fetches each list's first places with their photos in one query (embedded rows limited per list); nil when it fails.
    private func fetchCoverChunk(_ ids: [String]) async -> [String: [String]]? {
        do {
            let rows: [CoverListRow] = try await supabase.client
                .from("place_lists")
                .select("id, place_list_items(sort_order, places(thumbnail_url, photo_urls))")
                .in("id", values: ids)
                .order("sort_order", ascending: true, referencedTable: "place_list_items")
                .limit(coversPerList, referencedTable: "place_list_items")
                .execute()
                .value
            return groupPhotos(rows, for: ids)
        } catch {
            print("⚠️ [ExploreListsService] Cover photo lookup failed: \(error)")
            return nil
        }
    }

    /// Collects one distinct photo per place for each list, keeping list order; lists without photos map to [].
    private func groupPhotos(_ rows: [CoverListRow], for ids: [String]) -> [String: [String]] {
        var result = Dictionary(uniqueKeysWithValues: ids.map { ($0, [String]()) })
        for row in rows {
            var seen = Set<String>()
            let photos = (row.place_list_items ?? []).compactMap { $0.places.flatMap(Self.bestPhoto) }.filter { seen.insert($0).inserted }
            result[row.id] = Array(photos.prefix(coversPerList))
        }
        return result
    }

    /// Picks a place's most durable valid photo URL (stored images before expiring Google links).
    private static func bestPhoto(_ place: CoverPlaceRow) -> String? {
        let all = ([place.thumbnail_url] + (place.photo_urls ?? []).prefix(4).map { Optional($0) })
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { URL(string: $0) != nil }
        return ImageLoadingUtility.rankedPhotoURLs(all).first
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
