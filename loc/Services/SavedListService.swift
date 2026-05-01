//
//  SavedListService.swift
//  loc
//
//  Service for managing saved lists — saving/unsaving other users' public lists.
//

import Foundation

/// Service for saving and unsaving other users' public lists.
@MainActor
class SavedListService {
    // MARK: - Singleton
    static let shared = SavedListService()

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Save / Unsave

    /// Saves an external list to the current user's profile.
    func saveList(userId: String, listId: String) async throws {
        struct Params: Encodable {
            let user_id: String
            let list_id: String
        }

        try await supabase.client
            .from("saved_lists")
            .insert(Params(user_id: userId, list_id: listId))
            .execute()
    }

    /// Removes a saved list from the current user's profile.
    func unsaveList(userId: String, listId: String) async throws {
        try await supabase.client
            .from("saved_lists")
            .delete()
            .eq("user_id", value: userId)
            .eq("list_id", value: listId)
            .execute()
    }

    // MARK: - Queries

    /// Checks if a specific list is saved by the current user.
    func isListSaved(userId: String, listId: String) async throws -> Bool {
        struct Row: Decodable {
            let id: String
        }

        let rows: [Row] = try await supabase.client
            .from("saved_lists")
            .select("id")
            .eq("user_id", value: userId)
            .eq("list_id", value: listId)
            .limit(1)
            .execute()
            .value

        return !rows.isEmpty
    }

    /// Fetches all saved list IDs for the current user (for quick UI state checks).
    func fetchSavedListIds(userId: String) async throws -> Set<String> {
        struct Row: Decodable {
            let list_id: String
        }

        let rows: [Row] = try await supabase.client
            .from("saved_lists")
            .select("list_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        return Set(rows.map(\.list_id))
    }

    /// Fetches saved lists sorted by proximity to user location with pagination.
    func fetchSavedLists(
        userId: String,
        latitude: Double,
        longitude: Double,
        page: Int = 1,
        pageSize: Int = 6
    ) async throws -> [LightweightPlaceList] {
        struct Params: Encodable {
            let p_user_id: String
            let p_latitude: Double
            let p_longitude: Double
            let p_page: Int
            let p_page_size: Int
        }

        let params = Params(
            p_user_id: userId,
            p_latitude: latitude,
            p_longitude: longitude,
            p_page: page,
            p_page_size: pageSize
        )

        let lists: [LightweightPlaceList] = try await supabase.client
            .rpc("get_user_saved_lists", params: params)
            .execute()
            .value

        return lists
    }

    /// Returns the number of users who have saved a specific list.
    func getSaveCount(listId: String) async throws -> Int {
        struct Params: Encodable {
            let p_list_id: String
        }

        let count: Int = try await supabase.client
            .rpc("get_saved_list_count", params: Params(p_list_id: listId))
            .execute()
            .value

        return count
    }
}
