//
//  SupabaseUserService.swift
//  loc
//
//  User service using Supabase (replacement for Firebase UserService)
//

import Foundation
import Supabase
import PostgREST

@MainActor
class SupabaseUserService: ObservableObject {
    static let shared = SupabaseUserService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - User Profile
    
    func fetchUserById(userId: String) async throws -> ProfileData {
        let response: ProfileData = try await supabase.database
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    func saveUserProfile(uid: String, profileData: ProfileData) async throws {
        try await supabase.database
            .from("users")
            .upsert(profileData)
            .execute()
    }
    
    func searchUsers(query: String) async throws -> [ProfileData] {
        let queryLower = query.lowercased()
        
        let response: [ProfileData] = try await supabase.database
            .from("users")
            .select()
            .gte("full_name_lower", value: queryLower)
            .lte("full_name_lower", value: queryLower + "\u{f8ff}")
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Following/Followers
    
    func fetchFollowingProfilesData(for userId: String) async throws -> [ProfileData] {
        // Get following IDs
        let followingRecords: [Following] = try await supabase.database
            .from("following")
            .select()
            .eq("follower_id", value: userId)
            .execute()
            .value
        
        let followingIds = followingRecords.map { $0.following_id.uuidString }
        
        guard !followingIds.isEmpty else { return [] }
        
        // Fetch profiles
        let profiles: [ProfileData] = try await supabase.database
            .from("users")
            .select()
            .in("id", values: followingIds)
            .execute()
            .value
        
        return profiles
    }
    
    func fetchFollowerProfilesData(for userId: String) async throws -> [ProfileData] {
        // Get follower IDs
        let followerRecords: [Following] = try await supabase.database
            .from("following")
            .select()
            .eq("following_id", value: userId)
            .execute()
            .value
        
        let followerIds = followerRecords.map { $0.follower_id.uuidString }
        
        guard !followerIds.isEmpty else { return [] }
        
        // Fetch profiles
        let profiles: [ProfileData] = try await supabase.database
            .from("users")
            .select()
            .in("id", values: followerIds)
            .execute()
            .value
        
        return profiles
    }
    
    func getNumberFollowers(forUserId userId: String) async throws -> Int {
        let response = try await supabase.database
            .from("following")
            .select(count: .exact)
            .eq("following_id", value: userId)
            .execute()
        
        return response.count ?? 0
    }
    
    func getNumberFollowing(forUserId userId: String) async throws -> Int {
        let response = try await supabase.database
            .from("following")
            .select(count: .exact)
            .eq("follower_id", value: userId)
            .execute()
        
        return response.count ?? 0
    }
    
    func followUser(followerId: String, followingId: String) async throws {
        let follow = Following(
            id: UUID(),
            follower_id: UUID(uuidString: followerId)!,
            following_id: UUID(uuidString: followingId)!,
            followed_at: Date()
        )
        
        try await supabase.database
            .from("following")
            .insert(follow)
            .execute()
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws {
        try await supabase.database
            .from("following")
            .delete()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
    }
    
    func isFollowingUser(followerId: String, followingId: String) async throws -> Bool {
        let response = try await supabase.database
            .from("following")
            .select(count: .exact)
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
        
        return (response.count ?? 0) > 0
    }
    
    // MARK: - Favorites
    
    func addProfileFavorite(userId: String, place: DetailPlace) async throws {
        let favorite = Favorite(
            id: UUID(),
            user_id: UUID(uuidString: userId)!,
            place_id: place.id,
            timestamp: Date()
        )
        
        try await supabase.database
            .from("favorites")
            .insert(favorite)
            .execute()
    }
    
    func removeProfileFavorite(userId: String, placeId: String) async throws {
        try await supabase.database
            .from("favorites")
            .delete()
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .execute()
    }
    
    // MARK: - Place Notes
    
    func savePlaceNote(userId: String, placeNote: PlaceNote) async throws {
        try await supabase.database
            .from("place_notes")
            .upsert(placeNote)
            .execute()
    }
    
    func fetchPlaceNote(userId: String, placeId: String) async throws -> PlaceNote? {
        let response: [PlaceNote] = try await supabase.database
            .from("place_notes")
            .select()
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    func deletePlaceNote(userId: String, placeNoteId: String) async throws {
        try await supabase.database
            .from("place_notes")
            .delete()
            .eq("id", value: placeNoteId)
            .execute()
    }
    
    func fetchAllPlaceNotes(userId: String) async throws -> [PlaceNote] {
        let response: [PlaceNote] = try await supabase.database
            .from("place_notes")
            .select()
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - TikTok Place Flagging
    
    func saveTikTokPlaceFlag(flag: TikTokPlaceFlag) async throws {
        try await supabase.database
            .from("tiktok_place_flags")
            .upsert(flag)
            .execute()
    }
    
    func fetchTikTokPlaceFlags(userId: String) async throws -> [TikTokPlaceFlag] {
        let response: [TikTokPlaceFlag] = try await supabase.database
            .from("tiktok_place_flags")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func hasUserFlaggedPlace(userId: String, placeId: String) async throws -> TikTokPlaceFlag? {
        let response: [TikTokPlaceFlag] = try await supabase.database
            .from("tiktok_place_flags")
            .select()
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    func deleteTikTokPlaceFlag(userId: String, flagId: String) async throws {
        try await supabase.database
            .from("tiktok_place_flags")
            .delete()
            .eq("id", value: flagId)
            .execute()
    }
    
    // MARK: - External Places (TikTok imports)
    
    func saveExternalPlace(externalPlace: ExternalPlace, userId: String) async throws {
        try await supabase.database
            .from("external_places")
            .upsert(externalPlace)
            .execute()
    }
    
    func fetchUserExternalPlaces(userId: String) async throws -> [String: ExternalPlace] {
        let response: [ExternalPlace] = try await supabase.database
            .from("external_places")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // Convert to dictionary keyed by place_id
        return Dictionary(uniqueKeysWithValues: response.map { ($0.placeId, $0) })
    }
    
    func deleteTikTokPlace(userId: String, placeId: String) async throws {
        try await supabase.database
            .from("external_places")
            .delete()
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .execute()
    }
    
    // MARK: - FCM Token
    
    func updateFCMToken(userId: String, token: String) async throws {
        try await supabase.database
            .from("users")
            .update(["fcm_token": token])
            .eq("id", value: userId)
            .execute()
    }
    
    func getFCMTokens(for userIds: [String]) async throws -> [String] {
        guard !userIds.isEmpty else { return [] }
        
        // Split into batches of 100 (Supabase limit)
        var allTokens: [String] = []
        
        for batch in userIds.chunked(into: 100) {
            let response: [UserFCMToken] = try await supabase.database
                .from("users")
                .select("fcm_token")
                .in("id", values: batch)
                .execute()
                .value
            
            let tokens = response.compactMap { $0.fcm_token }
            allTokens.append(contentsOf: tokens)
        }
        
        return allTokens
    }
    
    // MARK: - Account Deletion
    
    func deleteUserAccount(userId: String) async throws {
        // With RLS and CASCADE DELETE, we can just delete the user record
        // All related data will be automatically deleted
        try await supabase.database
            .from("users")
            .delete()
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Compatibility Methods (callback-based)
    
    func fetchUserById(userId: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
        Task {
            do {
                let profile = try await fetchUserById(userId: userId)
                completion(.success(profile))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func fetchFollowingProfilesData(for userId: String, completion: @escaping ([ProfileData]?, Error?) -> Void) {
        Task {
            do {
                let profiles = try await fetchFollowingProfilesData(for: userId)
                completion(profiles, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func fetchFollowerProfilesData(for userId: String, completion: @escaping ([ProfileData]?, Error?) -> Void) {
        Task {
            do {
                let profiles = try await fetchFollowerProfilesData(for: userId)
                completion(profiles, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func getNumberFollowers(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        Task {
            do {
                let count = try await getNumberFollowers(forUserId: userId)
                completion(count, nil)
            } catch {
                completion(0, error)
            }
        }
    }
    
    func getNumberFollowing(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        Task {
            do {
                let count = try await getNumberFollowing(forUserId: userId)
                completion(count, nil)
            } catch {
                completion(0, error)
            }
        }
    }
    
    func updateFCMToken(userId: String, token: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await updateFCMToken(userId: userId, token: token)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}

// MARK: - Helper Models

struct Following: Codable {
    let id: UUID
    let follower_id: UUID
    let following_id: UUID
    let followed_at: Date
}

struct Favorite: Codable {
    let id: UUID
    let user_id: UUID
    let place_id: UUID
    let timestamp: Date
}

struct UserFCMToken: Codable {
    let fcm_token: String?
}

