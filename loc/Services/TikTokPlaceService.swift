//
//  TikTokPlaceService.swift
//  loc
//
//  Service for managing external videos and their associations with places
//

import Foundation

class ExternalPlaceService {
    nonisolated(unsafe) static let shared = ExternalPlaceService()
    private let supabase = SupabaseManager.shared

    private init() {}

    /// Fetch all places associated with a specific video for a user
    func fetchPlacesForVideo(videoId: String, userId: String) async throws -> [ExternalAssociatedPlace] {
        let response: [ExternalAssociatedPlace] = try await supabase.client
            .rpc("get_places_for_tiktok_video", params: [
                "p_video_id": videoId,
                "p_user_id": userId
            ])
            .execute()
            .value

        return response
    }

    /// Delete a video from a specific place in external_places
    /// Since each external_places row now contains only one URL, we delete the entire row
    func deleteVideoFromPlace(placeId: String, videoUrl: String, userId: String, externalPlaceId: String? = nil) async throws {
        // If external_place_id is provided, use it directly for deletion
        if let externalPlaceId = externalPlaceId {
            try await supabase.client
                .from("external_places")
                .delete()
                .eq("id", value: externalPlaceId)
                .execute()
            return
        }

        // Otherwise, find the row by URL
        struct ExternalPlaceRecord: Codable {
            let id: String
            let url: String?
        }

        let records: [ExternalPlaceRecord] = try await supabase.client
            .from("external_places")
            .select("id, url")
            .eq("place_id", value: placeId)
            .eq("user_id", value: userId)
            .eq("url", value: videoUrl)
            .execute()
            .value

        guard let record = records.first else {
            throw NSError(domain: "ExternalPlaceService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "External place record not found for URL"
            ])
        }

        // Delete the entire row (since each row = one video)
        try await supabase.client
            .from("external_places")
            .delete()
            .eq("id", value: record.id)
            .execute()
    }
}
