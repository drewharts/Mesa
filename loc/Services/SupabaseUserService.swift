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

                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(user, nil)
                }
            } catch {
                print("❌ [Supabase] Error fetching user by Supabase UID \(supabaseUid): \(error)")
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(nil, error)
                }
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
                
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(user, nil)
                }
            } catch {
                print("❌ [Supabase] Error fetching user \(userId): \(error)")
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(nil, error)
                }
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
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(followingIds, nil)
                }
            } catch {
                print("❌ [Supabase] Error fetching friends for \(userId): \(error)")
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(nil, error)
                }
            }
        }
    }
    
    func fetchProfiles(for userIds: [String], completion: @escaping ([User]?, Error?) -> Void) {
        Task {
            do {
                guard !userIds.isEmpty else {
                    await MainActor.run {
                        completion([], nil)
                    }
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
                
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(users, nil)
                }
            } catch {
                print("❌ [Supabase] Error fetching profiles: \(error)")
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(nil, error)
                }
            }
        }
    }
    
    func searchUsers(query: String, completion: @escaping ([User]?, Error?) -> Void) {
        Task {
            do {
                let users = try await searchUsers(query: query, limit: 20)
                await MainActor.run {
                    completion(users, nil)
                }
            } catch {
                print("❌ [Supabase] Error searching users for query '\(query)': \(error)")
                await MainActor.run {
                    completion(nil, error)
                }
            }
        }
    }
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            return []
        }
        
        let normalizedQuery = trimmedQuery
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
        
        guard !normalizedQuery.isEmpty else {
            return []
        }
        
        let likePattern = "%\(normalizedQuery)%"
        
        var uniqueRecords: [String: UserRecord] = [:]
        
        let fullNameMatches: [UserRecord] = try await supabase.client
            .from("users")
            .select("""
                id,
                first_name,
                last_name,
                email,
                profile_photo_url,
                full_name
            """)
            .ilike("full_name_lower", value: likePattern)
            .limit(limit)
            .execute()
            .value
        
        fullNameMatches.forEach { uniqueRecords[$0.id] = $0 }
        
        if trimmedQuery.contains("@") {
            let emailPattern = "%\(trimmedQuery.lowercased())%"
            let emailMatches: [UserRecord] = try await supabase.client
                .from("users")
                .select("""
                    id,
                    first_name,
                    last_name,
                    email,
                    profile_photo_url,
                    full_name
                """)
                .ilike("email", value: emailPattern)
                .limit(limit)
                .execute()
                .value
            
            emailMatches.forEach { uniqueRecords[$0.id] = $0 }
        }
        
        if uniqueRecords.isEmpty && normalizedQuery.contains(" ") {
            let tokens = normalizedQuery
                .split(separator: " ")
                .map(String.init)
                .filter { !$0.isEmpty }
            
            for token in tokens {
                let tokenPattern = "%\(token)%"
                let tokenMatches: [UserRecord] = try await supabase.client
                    .from("users")
                    .select("""
                        id,
                        first_name,
                        last_name,
                        email,
                        profile_photo_url,
                        full_name
                    """)
                    .ilike("full_name_lower", value: tokenPattern)
                    .limit(limit)
                    .execute()
                    .value
                
                tokenMatches.forEach { uniqueRecords[$0.id] = $0 }
                
                if uniqueRecords.count >= limit {
                    break
                }
            }
        }
        
        let sortedRecords = uniqueRecords
            .values
            .sorted { $0.full_name.localizedCaseInsensitiveCompare($1.full_name) == .orderedAscending }
            .prefix(limit)
        
        return sortedRecords.map { record in
            User(
                id: record.id,
                firstName: record.first_name,
                lastName: record.last_name,
                email: record.email,
                profilePhotoURL: record.profile_photo_url.flatMap { URL(string: $0) },
                fullName: record.full_name
            )
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
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(nil)
                }
            } catch {
                print("❌ [Supabase] Error updating FCM token: \(error)")
                // Ensure completion is called on main thread
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }
    
    // MARK: - Follower/Following Counts (Optimized - Count Only!)
    
    /// Get follower count - FAST! (count query only, no profile data)
    func getNumberFollowers(forUserId userId: String) async throws -> Int {
        let response = try await supabase.client
            .from("following")
            .select("*", head: false, count: .exact)
            .eq("following_id", value: userId)
            .execute()
        
        let count = response.count ?? 0
        return count
    }
    
    /// Get following count - FAST! (count query only, no profile data)
    func getNumberFollowing(forUserId userId: String) async throws -> Int {
        let response = try await supabase.client
            .from("following")
            .select("*", head: false, count: .exact)
            .eq("follower_id", value: userId)
            .execute()
        
        let count = response.count ?? 0
        return count
    }
    
    /// Get my places count - FAST! (count query only, no place data)
    func getNumberMyPlaces(forUserId userId: String) async throws -> Int {
        
        let response = try await supabase.client
            .from("my_places")
            .select("*", head: false, count: .exact)
            .eq("user_id", value: userId)
            .execute()
        
        let count = response.count ?? 0
        return count
    }
    
    /// Get total list count for a user - FAST! (count query only)
    func getTotalListCount(forUserId userId: String) async throws -> Int {
        struct UserStats: Codable {
            let lists_count: Int
        }
        
        let response: [UserStats] = try await supabase.client
            .rpc("get_user_stats", params: ["p_user_id": userId])
            .execute()
            .value
        
        return response.first?.lists_count ?? 0
    }
    
    /// Get total unique places count for a user (saved + reviewed + created)
    /// Uses database function that deduplicates across all sources
    func getTotalPlacesCount(forUserId userId: String) async throws -> Int {
        struct PlacesCount: Codable {
            let total_places_count: Int
        }
        
        let response: [PlacesCount] = try await supabase.client
            .rpc("get_user_total_places_count", params: ["p_user_id": userId])
            .execute()
            .value
        
        return response.first?.total_places_count ?? 0
    }
    
    /// Check if a user is following another user
    func isFollowingUser(followerId: String, followingId: String) async throws -> Bool {
        struct FollowingRecord: Codable {
            let follower_id: String
            let following_id: String
        }
        
        let response: [FollowingRecord] = try await supabase.client
            .from("following")
            .select()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    /// Follow a user
    func followUser(followerId: String, followingId: String) async throws {
        struct FollowRecord: Codable {
            let follower_id: String
            let following_id: String
        }
        
        let record = FollowRecord(
            follower_id: followerId,
            following_id: followingId
        )
        
        try await supabase.client
            .from("following")
            .insert(record)
            .execute()
    }
    
    /// Unfollow a user
    func unfollowUser(followerId: String, followingId: String) async throws {
        try await supabase.client
            .from("following")
            .delete()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
    }
    
    /// Fetch user favorites using optimized SQL function
    /// Returns lightweight favorite data for display without full place details
    func fetchUserFavorites(userId: String) async throws -> [FavoritePlace] {
        struct Params: Encodable {
            let p_user_id: String
        }
        
        let params = Params(p_user_id: userId)
        
        let favorites: [FavoritePlace] = try await supabase.client
            .rpc("get_user_favorite_places", params: params)
            .execute()
            .value
        
        return favorites
    }
    
    /// Fetch user's place lists sorted by proximity to user's location
    /// Returns lightweight list data with pagination support
    func fetchPlaceListsByProximity(userId: String, userLatitude: Double, userLongitude: Double, page: Int = 1, pageSize: Int = 10) async throws -> [LightweightPlaceList] {
        
        struct Params: Encodable {
            let p_user_id: String
            let p_user_location: String // PostGIS geometry as WKT
            let p_page: Int
            let p_page_size: Int
        }
        
        // Convert lat/lng to PostGIS POINT geometry in EWKT format with SRID
        // Use SRID 4326 (WGS84) for GPS coordinates
        let userLocation = "SRID=4326;POINT(\(userLongitude) \(userLatitude))"
        print("📍 [Supabase] Using PostGIS POINT: \(userLocation)")
        
        let params = Params(
            p_user_id: userId,
            p_user_location: userLocation,
            p_page: page,
            p_page_size: pageSize
        )
        
        do {
            let lists: [LightweightPlaceList] = try await supabase.client
                .rpc("get_paginated_user_place_lists_by_proximity", params: params)
                .execute()
                .value
            
            print("✅ [Supabase] Fetched \(lists.count) place lists")
            if lists.count > 0 {
                print("   First list: \(lists[0].name) (ID: \(lists[0].list_id), distance: \(lists[0].distance_meters ?? 0)m)")
            } else {
                print("⚠️ [Supabase] No place lists found for user \(userId)")
            }
            
            return lists
        } catch {
            print("❌ [Supabase] Error fetching place lists: \(error)")
            print("   Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch a single place list by ID
    /// Used for deep link navigation when the list isn't in the first paginated results
    func fetchPlaceListById(listId: String) async throws -> LightweightPlaceList? {
        struct Params: Encodable {
            let p_list_id: String
        }
        
        let params = Params(p_list_id: listId)
        
        do {
            let lists: [LightweightPlaceList] = try await supabase.client
                .rpc("get_single_place_list_by_id", params: params)
                .execute()
                .value
            
            print("✅ [Supabase] Fetched place list by ID: \(listId), found: \(lists.first?.name ?? "nil")")
            return lists.first
        } catch {
            print("❌ [Supabase] Error fetching place list by ID: \(error)")
            throw error
        }
    }
    
    /// Search place lists by name with pagination (server-side filtering)
    func searchPlaceLists(userId: String, query: String, page: Int = 1, pageSize: Int = 20) async throws -> [LightweightPlaceList] {
        struct SearchListRecord: Codable {
            let id: String
            let name: String
            let is_public: Bool?
            let image: String?
            let created_at: String?
            let updated_at: String?
        }
        
        // Fetch matching lists from database
        let response: [SearchListRecord] = try await supabase.client
            .from("place_lists")
            .select("id, name, is_public, image, created_at, updated_at")
            .eq("user_id", value: userId)
            .ilike("name", pattern: "%\(query)%")
            .order("name", ascending: true)
            .range(from: (page - 1) * pageSize, to: page * pageSize - 1)
            .execute()
            .value
        
        // Convert to LightweightPlaceList format
        return response.map { record in
            LightweightPlaceList(
                list_id: record.id,
                name: record.name,
                is_public: record.is_public ?? false,
                image: record.image,
                created_at: record.created_at ?? ISO8601DateFormatter().string(from: Date()),
                updated_at: record.updated_at ?? ISO8601DateFormatter().string(from: Date()),
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
        }
    }
    
    /// Fetch places within a place list with pagination
    func fetchPlacesForPlaceList(listId: String, page: Int = 1, pageSize: Int = 6) async throws -> [LightweightPlace] {
        struct Params: Encodable {
            let p_list_id: String
            let p_page: Int
            let p_page_size: Int
        }
        
        let params = Params(
            p_list_id: listId,
            p_page: page,
            p_page_size: pageSize
        )
        
        let places: [LightweightPlace] = try await supabase.client
            .rpc("get_paginated_place_list_places", params: params)
            .execute()
            .value
        
        return places
    }
    
    /// Fetch user's created places (lightweight data for tiles, paginated)
    func fetchUserCreatedPlaces(userId: String, limit: Int = 8, offset: Int = 0) async throws -> [LightweightPlace] {
        struct Params: Encodable {
            let p_user_id: String
            let p_limit: Int
            let p_offset: Int
        }
        
        let params = Params(
            p_user_id: userId,
            p_limit: limit,
            p_offset: offset
        )
        
        let places: [LightweightPlace] = try await supabase.client
            .rpc("get_user_created_places", params: params)
            .execute()
            .value
        
        return places
    }
    
    // MARK: - Follower/Following Profile Data (Lazy - Load on Demand!)
    
    /// Fetch follower profiles - LAZY! Only call when user clicks "Followers"
    /// Uses pagination for optimal performance
    func fetchFollowerProfilesData(for userId: String, limit: Int, offset: Int = 0) async throws -> [ProfileData] {
        let pageNumber = (offset / limit) + 1
        
        struct PaginatedParams: Encodable {
            let user_id: String
            let page_size: Int
            let page_number: Int
        }
        
        let params = PaginatedParams(
            user_id: userId,
            page_size: limit,
            page_number: pageNumber
        )
        
        let profiles: [ProfileData] = try await supabase.client
            .rpc("get_follower_profiles_paginated", params: params)
            .execute()
            .value
        
        return profiles
    }
    
    /// Fetch following profiles - LAZY! Only call when user clicks "Following"
    /// Uses pagination for optimal performance
    func fetchFollowingProfilesData(for userId: String, limit: Int, offset: Int = 0) async throws -> [ProfileData] {
        let pageNumber = (offset / limit) + 1
        
        struct PaginatedParams: Encodable {
            let user_id: String
            let page_size: Int
            let page_number: Int
        }
        
        let params = PaginatedParams(
            user_id: userId,
            page_size: limit,
            page_number: pageNumber
        )
        
        let profiles: [ProfileData] = try await supabase.client
            .rpc("get_following_profiles_paginated", params: params)
            .execute()
            .value
        
        return profiles
    }
    
    /// ✅ NEW: Fetch following user IDs only (not full profiles) - SUPER FAST!
    func fetchFollowingUserIds(userId: String) async throws -> [String] {
        let followRecords: [FollowingRecord] = try await supabase.client
            .from("following")
            .select("follower_id, following_id, created_at")
            .eq("follower_id", value: userId)
            .execute()
            .value
        
        let followingIds = followRecords.map { $0.following_id }
        
        return followingIds
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
    
    /// Fetch user's external places (TikTok places, lightweight data for tiles, paginated)
    func fetchUserExternalPlaces(userId: String, limit: Int = 8, offset: Int = 0) async throws -> [LightweightPlace] {
        struct Params: Encodable {
            let p_user_id: String
            let p_limit: Int
            let p_offset: Int
        }
        
        let params = Params(
            p_user_id: userId,
            p_limit: limit,
            p_offset: offset
        )
        
        let places: [LightweightPlace] = try await supabase.client
            .rpc("get_user_external_places", params: params)
            .execute()
            .value
        
        return places
    }
    
    /// Fetch user's reviewed places (lightweight data for tiles, paginated - server-side)
    func fetchUserReviewedPlaces(userId: String, limit: Int = 8, offset: Int = 0) async throws -> [LightweightPlace] {
        struct Params: Encodable {
            let p_user_id: String
            let p_limit: Int
            let p_offset: Int
        }
        
        let params = Params(
            p_user_id: userId,
            p_limit: limit,
            p_offset: offset
        )
        
        let places: [LightweightPlace] = try await supabase.client
            .rpc("get_user_reviewed_places", params: params)
            .execute()
            .value
        
        return places
    }
    
    func fetchExternalPlaceURLs(placeIds: [String], userId: String) async throws -> [String: String] {
        guard !placeIds.isEmpty else {
            return [:]
        }
        
        struct ExternalPlaceUrlRecord: Codable {
            let place_id: String
            let url: String?
        }
        
        let records: [ExternalPlaceUrlRecord] = try await supabase.client
            .from("external_places")
            .select("place_id,url")
            .eq("user_id", value: userId)
            .in("place_id", values: placeIds)
            .execute()
            .value
        
        var result: [String: String] = [:]
        for record in records {
            if let url = record.url, !url.isEmpty {
                result[record.place_id] = url
            }
        }
        
        return result
    }
    
    func fetchExternalReviewImages(for placeIds: [String]) async throws -> [String: String] {
        guard !placeIds.isEmpty else {
            return [:]
        }
        
        struct ExternalReviewMedia: Codable {
            let type: String?
            let imageUrl: String?
            
            enum CodingKeys: String, CodingKey {
                case type
                case imageUrl
            }
        }
        
        struct ExternalReviewRecord: Codable {
            let place_id: String
            let media: [ExternalReviewMedia]?
        }
        
        let records: [ExternalReviewRecord] = try await supabase.client
            .from("external_reviews")
            .select("place_id, media")
            .in("place_id", values: placeIds)
            .order("review_iso_date", ascending: false)
            .execute()
            .value
        
        var result: [String: String] = [:]
        
        for record in records {
            guard result[record.place_id] == nil else { continue }
            guard let mediaItems = record.media else { continue }
            if let imageUrl = mediaItems.first(where: { ($0.type ?? "").lowercased() == "image" && ($0.imageUrl?.isEmpty == false) })?.imageUrl {
                result[record.place_id] = imageUrl
            }
        }
        
        return result
    }
    
    /// Fetch review images from the regular reviews table (user-created reviews)
    /// This is a fallback when get_latest_review_photo SQL function returns NULL
    func fetchRegularReviewImages(for placeIds: [String]) async throws -> [String: String] {
        guard !placeIds.isEmpty else {
            return [:]
        }
        
        struct ReviewImageRecord: Codable {
            let place_id: String
            let images: [String]?
        }
        
        let records: [ReviewImageRecord] = try await supabase.client
            .from("reviews")
            .select("place_id, images")
            .in("place_id", values: placeIds)
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        var result: [String: String] = [:]
        
        for record in records {
            // Skip if we already have an image for this place
            guard result[record.place_id] == nil else { continue }
            // Get the first non-empty image URL
            if let images = record.images,
               let firstImage = images.first(where: { !$0.isEmpty }) {
                result[record.place_id] = firstImage
            }
        }
        
        return result
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
    let created_at: String?
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

/// Lightweight favorite place data for display
struct FavoritePlace: Codable, Identifiable {
    let place_id: String
    let name: String
    let latest_review_photo: String?
    // Note: coordinate is returned by SQL but we don't need it for display
    // Ignoring it during decoding by not declaring it here won't work with strict Codable
    // So we'll need to make it optional or use CodingKeys
    
    var id: String { place_id }
    
    enum CodingKeys: String, CodingKey {
        case place_id
        case name
        case latest_review_photo
        // Intentionally omitting coordinate - we don't need it
    }
}

/// Lightweight place list data for display (sorted by proximity)

// MARK: - Place List Management

extension SupabaseUserService {
    /// Add a place to a list
    func addPlaceToList(listId: String, placeId: String) async throws {
        // First, get the current max sort_order for this list
        let maxOrderResponse = try await supabase.client
            .from("place_list_items")
            .select("sort_order")
            .eq("list_id", value: listId)
            .order("sort_order", ascending: false)
            .limit(1)
            .execute()
        
        let maxOrder = (try? JSONDecoder().decode([SortOrder].self, from: maxOrderResponse.data).first?.sort_order) ?? -1
        let nextOrder = maxOrder + 1
        
        // Create insert struct
        struct PlaceListItem: Encodable {
            let list_id: String
            let place_id: String
            let sort_order: Int
        }
        
        let newItem = PlaceListItem(
            list_id: listId,
            place_id: placeId,
            sort_order: nextOrder
        )
        
        // Insert the new item
        try await supabase.client
            .from("place_list_items")
            .insert(newItem)
            .execute()
        
        print("✅ [Supabase] Added place \(placeId) to list \(listId) at position \(nextOrder)")
    }
    
    /// Remove a place from a list
    func removePlaceFromList(listId: String, placeId: String) async throws {
        try await supabase.client
            .from("place_list_items")
            .delete()
            .eq("list_id", value: listId)
            .eq("place_id", value: placeId)
            .execute()
        
        print("✅ [Supabase] Removed place \(placeId) from list \(listId)")
    }
    
    /// Check if a place is in a list
    func checkPlaceInList(listId: String, placeId: String) async throws -> Bool {
        let response = try await supabase.client
            .from("place_list_items")
            .select("place_id")
            .eq("list_id", value: listId)
            .eq("place_id", value: placeId)
            .limit(1)
            .execute()
        
        let items = try JSONDecoder().decode([PlaceListItemCheck].self, from: response.data)
        return !items.isEmpty
    }
    
    // Helper struct for checking if place exists in list
    private struct PlaceListItemCheck: Codable {
        let place_id: String
    }
    
    // Helper struct for decoding sort_order
    private struct SortOrder: Codable {
        let sort_order: Int
    }
    
    // MARK: - External Places Management
    
    /// Save an external place (TikTok video) to Supabase
    func saveExternalPlace(externalPlace: ExternalPlace, userId: String) async throws {
        print("💾 [SupabaseUserService] Saving external place for user: \(userId), place: \(externalPlace.placeId)")
        
        // First verify the user exists in the users table
        do {
            struct UserIdRecord: Decodable {
                let id: String
            }
            
            let userCheck: [UserIdRecord] = try await supabase.client
                .from("users")
                .select("id")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            
            if userCheck.isEmpty {
                print("❌ [SupabaseUserService] User ID \(userId) does not exist in users table")
                throw NSError(domain: "SupabaseUserService", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "User not found in users table. Make sure the user profile exists."
                ])
            }
            
            print("✅ [SupabaseUserService] Verified user exists in users table")
        } catch {
            print("❌ [SupabaseUserService] Error verifying user: \(error.localizedDescription)")
            throw error
        }
        
        // Generate a new UUID for the external_place entry
        let externalPlaceId = UUID().uuidString
        
        // Create insert struct matching the database schema
        struct ExternalPlaceRecord: Encodable {
            let id: String
            let user_id: String
            let place_id: String
            let source: String
            let url: String?
            let added_at: String // ISO8601 formatted date
        }
        
        let formatter = ISO8601DateFormatter()
        let newRecord = ExternalPlaceRecord(
            id: externalPlaceId,
            user_id: userId,
            place_id: externalPlace.placeId,
            source: externalPlace.source,
            url: externalPlace.url,
            added_at: formatter.string(from: externalPlace.addedAt)
        )
        
        // Insert into external_places table
        try await supabase.client
            .from("external_places")
            .insert(newRecord)
            .execute()
        
        print("✅ [SupabaseUserService] Successfully saved external place: \(externalPlaceId)")
    }
    
    // MARK: - External Place Deletion
    
    /// Deletes all external_places records for a user and place combination
    /// Single Responsibility: Execute Supabase delete operation for external places
    /// - Parameters:
    ///   - userId: The user's ID (Firebase UID)
    ///   - placeId: The place ID to remove from user's saved TikToks
    /// - Throws: Database errors if deletion fails
    func deleteExternalPlaces(userId: String, placeId: String) async throws {
        try await supabase.client
            .from("external_places")
            .delete()
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .execute()
        
        print("✅ [SupabaseUserService] Deleted external places for user \(userId), place \(placeId)")
    }
}

