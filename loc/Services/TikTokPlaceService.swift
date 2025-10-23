//
//  TikTokPlaceService.swift
//  loc
//
//  Service for managing TikTok videos and their associations with places
//

import Foundation

class TikTokPlaceService {
    static let shared = TikTokPlaceService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetch all places associated with a specific TikTok video for a user
    func fetchPlacesForTikTok(videoId: String, userId: String) async throws -> [TikTokAssociatedPlace] {
        let response: [TikTokAssociatedPlace] = try await supabase.client
            .rpc("get_places_for_tiktok_video", params: [
                "p_video_id": videoId,
                "p_user_id": userId
            ])
            .execute()
            .value
        
        return response
    }
    
    /// Delete a TikTok video from a specific place in external_places
    func deleteTikTokFromPlace(placeId: String, videoId: String, userId: String) async throws {
        // First, fetch the current row
        struct ExternalPlaceRecord: Codable {
            let id: String
            let tiktok_videos: [AnyCodable]
        }
        
        let currentRecords: [ExternalPlaceRecord] = try await supabase.client
            .from("external_places")
            .select()
            .eq("place_id", value: placeId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        guard let currentRecord = currentRecords.first else {
            throw NSError(domain: "TikTokPlaceService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "External place record not found"
            ])
        }
        
        // Filter out the TikTok with the matching video_id
        let updatedVideos = currentRecord.tiktok_videos.compactMap { video -> [String: Any]? in
            guard let videoDict = video.value as? [String: Any],
                  let thisVideoId = videoDict["video_id"] as? String else {
                return nil
            }
            
            // Keep all videos except the one we're deleting
            return thisVideoId == videoId ? nil : videoDict
        }
        
        if updatedVideos.isEmpty {
            // If no TikToks left, delete the entire row
            try await supabase.client
                .from("external_places")
                .delete()
                .eq("id", value: currentRecord.id)
                .execute()
        } else {
            // Update with remaining TikToks (convert to AnyCodable for encoding)
            let encodableVideos = updatedVideos.map { AnyCodable($0) }
            try await supabase.client
                .from("external_places")
                .update(["tiktok_videos": encodableVideos])
                .eq("id", value: currentRecord.id)
                .execute()
        }
    }
}

