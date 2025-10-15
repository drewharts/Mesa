//
//  SupabaseUserService.swift
//  loc
//
//  User service using Supabase (replacement for Firebase UserService)
//

import Foundation
import Supabase

@MainActor
class SupabaseUserService: ObservableObject {
    static let shared = SupabaseUserService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - User Profile (matching Firebase UserService interface)

    func fetchUserBySupabaseUid(supabaseUid: String, completion: @escaping (User?, Error?) -> Void) {
        Task {
            do {
                let response: UserRecord = try await supabase.client
                    .from("users")
                    .select()
                    .eq("supabase_uid", value: supabaseUid)
                    .single()
                    .execute()
                    .value

                // Convert UserRecord to User
                let user = User(
                    id: response.id,
                    firstName: response.first_name,
                    lastName: response.last_name,
                    email: response.email,
                    profilePhotoURL: response.profile_photo_url.flatMap { URL(string: $0) },
                    fullName: response.full_name
                )

                completion(user, nil)
            } catch {
                print("❌ [Supabase] Error fetching user by Supabase UID \(supabaseUid): \(error)")
                completion(nil, error)
            }
        }
    }

    func fetchUserBySupabaseUid(supabaseUid: String) async throws -> User {
        let response: UserRecord = try await supabase.client
            .from("users")
            .select()
            .eq("supabase_uid", value: supabaseUid)
            .single()
            .execute()
            .value

        // Convert UserRecord to User
        return User(
            id: response.id,
            firstName: response.first_name,
            lastName: response.last_name,
            email: response.email,
            profilePhotoURL: response.profile_photo_url.flatMap { URL(string: $0) },
            fullName: response.full_name
        )
    }

    func fetchUser(userId: String, completion: @escaping (User?, Error?) -> Void) {
        Task {
            do {
                let response: UserRecord = try await supabase.client
                    .from("users")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                // Convert UserRecord to User
                let user = User(
                    id: response.id,
                    firstName: response.first_name,
                    lastName: response.last_name,
                    email: response.email,
                    profilePhotoURL: response.profile_photo_url.flatMap { URL(string: $0) },
                    fullName: response.full_name
                )
                
                completion(user, nil)
            } catch {
                print("❌ [Supabase] Error fetching user \(userId): \(error)")
                completion(nil, error)
            }
        }
    }
    
    func fetchFriends(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        Task {
            do {
                let followingRecords: [FollowingRecord] = try await supabase.client
                    .from("following")
                    .select()
                    .eq("follower_id", value: userId)
                    .execute()
                    .value
                
                let followingIds = followingRecords.map { $0.following_id }
                completion(followingIds, nil)
            } catch {
                print("❌ [Supabase] Error fetching friends for \(userId): \(error)")
                completion(nil, error)
            }
        }
    }
    
    func fetchProfiles(for userIds: [String], completion: @escaping ([User]?, Error?) -> Void) {
        Task {
            do {
                guard !userIds.isEmpty else {
                    completion([], nil)
                    return
                }
                
                let response: [UserRecord] = try await supabase.client
                    .from("users")
                    .select()
                    .in("id", values: userIds)
                    .execute()
                    .value
                
                let users = response.map { record in
                    User(
                        id: record.id,
                        firstName: record.first_name,
                        lastName: record.last_name,
                        email: record.email,
                        profilePhotoURL: record.profile_photo_url.flatMap { URL(string: $0) },
                        fullName: record.full_name
                    )
                }
                
                completion(users, nil)
            } catch {
                print("❌ [Supabase] Error fetching profiles: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func fetchFollowingProfiles(for userId: String, completion: @escaping ([User]?, Error?) -> Void) {
        fetchFriends(userId: userId) { followingIds, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let followingIds = followingIds, !followingIds.isEmpty else {
                completion([], nil)
                return
            }
            
            self.fetchProfiles(for: followingIds, completion: completion)
        }
    }
    
    func updateFCMToken(userId: String, token: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("users")
                    .update(["fcm_token": token])
                    .eq("id", value: userId)
                    .execute()
                
                print("✅ [Supabase] FCM token updated for user \(userId)")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error updating FCM token: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Follower/Following Counts (Optimized - Count Only!)
    
    /// Get follower count - FAST! (count query only, no profile data)
    func getNumberFollowers(forUserId userId: String) async throws -> Int {
        print("🔢 [Supabase] Fetching follower COUNT for user: \(userId)")
        
        struct CountResult: Codable {
            let count: Int
        }
        
        let response = try await supabase.client
            .from("following")
            .select("*", head: false, count: .exact)
            .eq("following_id", value: userId)
            .execute()
        
        let count = response.count ?? 0
        print("✅ [Supabase] User has \(count) followers")
        return count
    }
    
    /// Get following count - FAST! (count query only, no profile data)
    func getNumberFollowing(forUserId userId: String) async throws -> Int {
        print("🔢 [Supabase] Fetching following COUNT for user: \(userId)")
        
        let response = try await supabase.client
            .from("following")
            .select("*", head: false, count: .exact)
            .eq("follower_id", value: userId)
            .execute()
        
        let count = response.count ?? 0
        print("✅ [Supabase] User is following \(count) people")
        return count
    }
    
    // MARK: - Follower/Following Profile Data (Lazy - Load on Demand!)
    
    /// Fetch follower profiles - LAZY! Only call when user clicks "Followers"
    /// With optional pagination for progressive loading
    func fetchFollowerProfilesData(for userId: String, limit: Int? = nil, offset: Int = 0) async throws -> [ProfileData] {
        let limitStr = limit.map { " (first \($0))" } ?? ""
        print("👥 [Supabase] Fetching follower PROFILES for user\(limitStr)...")
        let startTime = Date()
        
        // Step 1: Get follower IDs from following table (with pagination)
        var query = supabase.client
            .from("following")
            .select()
            .eq("following_id", value: userId)
            .order("followed_at", ascending: false) // Most recent first
        
        if let limit = limit {
            query = query.limit(limit).range(from: offset, to: offset + limit - 1)
        }
        
        let followRecords: [FollowingRecord] = try await query
            .execute()
            .value
        
        let followerIds = followRecords.map { $0.follower_id }
        
        guard !followerIds.isEmpty else {
            print("✅ [Supabase] No followers found")
            return []
        }
        
        print("🔍 [Supabase] Found \(followerIds.count) follower IDs, fetching profiles...")
        
        // Step 2: Fetch user profiles for those IDs
        let userRecords: [ProfileDataRecord] = try await supabase.client
            .from("users")
            .select()
            .in("id", values: followerIds)
            .execute()
            .value
        
        let profiles = userRecords.map { convertToProfileData($0) }
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ [Supabase] Fetched \(profiles.count) follower profiles in \(String(format: "%.2f", duration))s")
        
        return profiles
    }
    
    /// Fetch following profiles - LAZY! Only call when user clicks "Following"
    /// With optional pagination for progressive loading
    func fetchFollowingProfilesData(for userId: String, limit: Int? = nil, offset: Int = 0) async throws -> [ProfileData] {
        let limitStr = limit.map { " (first \($0))" } ?? ""
        print("👥 [Supabase] Fetching following PROFILES for user\(limitStr)...")
        let startTime = Date()
        
        // Step 1: Get following IDs from following table (with pagination)
        var query = supabase.client
            .from("following")
            .select()
            .eq("follower_id", value: userId)
            .order("followed_at", ascending: false) // Most recent first
        
        if let limit = limit {
            query = query.limit(limit).range(from: offset, to: offset + limit - 1)
        }
        
        let followRecords: [FollowingRecord] = try await query
            .execute()
            .value
        
        let followingIds = followRecords.map { $0.following_id }
        
        guard !followingIds.isEmpty else {
            print("✅ [Supabase] User is not following anyone")
            return []
        }
        
        print("🔍 [Supabase] Found \(followingIds.count) following IDs, fetching profiles...")
        
        // Step 2: Fetch user profiles for those IDs
        let userRecords: [ProfileDataRecord] = try await supabase.client
            .from("users")
            .select()
            .in("id", values: followingIds)
            .execute()
            .value
        
        let profiles = userRecords.map { convertToProfileData($0) }
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ [Supabase] Fetched \(profiles.count) following profiles in \(String(format: "%.2f", duration))s")
        
        return profiles
    }
    
    // MARK: - Helper: Convert UserRecord to ProfileData
    
    private func convertToProfileData(_ record: ProfileDataRecord) -> ProfileData {
        let fullName = record.full_name
        return ProfileData(
            id: record.id,
            firstName: record.first_name,
            lastName: record.last_name,
            email: record.email,
            profilePhotoURL: record.profile_photo_url.flatMap { URL(string: $0) },
            phoneNumber: record.phone_number ?? "",
            fullNameLower: fullName.lowercased(),
            fullName: fullName,
            fcmToken: record.fcm_token
        )
    }
    
    // MARK: - Additional methods used by the app
    
    func deleteAccount(userId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                // Delete user record (cascading deletes will handle related data)
                try await supabase.client
                    .from("users")
                    .delete()
                    .eq("id", value: userId)
                    .execute()
                
                print("✅ [Supabase] Account deleted for user \(userId)")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error deleting account: \(error)")
                completion(error)
            }
        }
    }
}

// MARK: - Supabase Data Models

struct UserRecord: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String
    let profile_photo_url: String?
    let full_name: String
}

struct FollowingRecord: Codable {
    let follower_id: String
    let following_id: String
}

struct ProfileDataRecord: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String
    let profile_photo_url: String?
    let phone_number: String?
    let full_name: String
    let fcm_token: String?
}

