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

