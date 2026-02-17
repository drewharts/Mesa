//
//  SupabaseUserService.swift
//  loc
//
//  User service using Supabase for user data operations.
//

import Foundation
import Supabase

@MainActor
class SupabaseUserService: ObservableObject {
    static let shared = SupabaseUserService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - User Profile

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
    
    /// Instagram-style user search with prefix/word-boundary matching
    /// - "Jo" matches "John Smith" ✅ (name starts with query)
    /// - "Sm" matches "John Smith" ✅ (word starts with query)
    /// - "ohn" does NOT match "John Smith" ❌ (middle of word)
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
        
        // Instagram-style prefix patterns:
        // 1. Name starts with query: "jo" matches "john smith"
        let startsWithPattern = "\(normalizedQuery)%"
        // 2. Any word starts with query: "sm" matches "john smith" (space before)
        let wordBoundaryPattern = "% \(normalizedQuery)%"
        
        var prefixMatches: [String: UserRecord] = [:]
        var wordBoundaryMatches: [String: UserRecord] = [:]
        
        // Priority 1: Names that START with the query (highest relevance)
        let startsWithResults: [UserRecord] = try await supabase.client
            .from("users")
            .select("""
                id,
                first_name,
                last_name,
                email,
                profile_photo_url,
                full_name
            """)
            .ilike("full_name_lower", pattern: startsWithPattern)
            .limit(limit)
            .execute()
            .value
        
        startsWithResults.forEach { prefixMatches[$0.id] = $0 }
        
        // Priority 2: Any word in name starts with query (if we need more results)
        if prefixMatches.count < limit {
            let wordBoundaryResults: [UserRecord] = try await supabase.client
                .from("users")
                .select("""
                    id,
                    first_name,
                    last_name,
                    email,
                    profile_photo_url,
                    full_name
                """)
                .ilike("full_name_lower", pattern: wordBoundaryPattern)
                .limit(limit)
                .execute()
                .value
            
            // Only add if not already in prefix matches
            wordBoundaryResults.forEach { record in
                if prefixMatches[record.id] == nil {
                    wordBoundaryMatches[record.id] = record
                }
            }
        }
        
        // Email search (only if query contains @)
        var emailMatches: [String: UserRecord] = [:]
        if trimmedQuery.contains("@") {
            let emailPattern = "\(trimmedQuery.lowercased())%"
            let emailResults: [UserRecord] = try await supabase.client
                .from("users")
                .select("""
                    id,
                    first_name,
                    last_name,
                    email,
                    profile_photo_url,
                    full_name
                """)
                .ilike("email", pattern: emailPattern)
                .limit(limit)
                .execute()
                .value
            
            emailResults.forEach { record in
                if prefixMatches[record.id] == nil && wordBoundaryMatches[record.id] == nil {
                    emailMatches[record.id] = record
                }
            }
        }
        
        // Combine results with priority ordering:
        // 1. Prefix matches (name starts with query) - sorted alphabetically
        // 2. Word boundary matches (word starts with query) - sorted alphabetically
        // 3. Email matches - sorted alphabetically
        let sortedPrefixMatches = prefixMatches.values
            .sorted { $0.full_name.localizedCaseInsensitiveCompare($1.full_name) == .orderedAscending }
        
        let sortedWordBoundaryMatches = wordBoundaryMatches.values
            .sorted { $0.full_name.localizedCaseInsensitiveCompare($1.full_name) == .orderedAscending }
        
        let sortedEmailMatches = emailMatches.values
            .sorted { $0.full_name.localizedCaseInsensitiveCompare($1.full_name) == .orderedAscending }
        
        let combinedRecords = Array((sortedPrefixMatches + sortedWordBoundaryMatches + sortedEmailMatches).prefix(limit))
        
        return combinedRecords.map { record in
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
                // Try to update by id OR supabase_uid since we might receive either
                // (id is the legacy user ID, supabase_uid is the Supabase auth ID)
                try await supabase.client
                    .from("users")
                    .update(["fcm_token": token])
                    .or("id.eq.\(userId),supabase_uid.eq.\(userId)")
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
    
    /// Gets external places count, optionally filtered to a map viewport.
    func getNumberExternalPlaces(forUserId userId: String, viewport: (minLon: Double, minLat: Double, maxLon: Double, maxLat: Double)? = nil) async throws -> Int {
        if let viewport = viewport {
            struct ViewportCountParams: Encodable {
                let p_user_id: String
                let p_min_lon: Double
                let p_min_lat: Double
                let p_max_lon: Double
                let p_max_lat: Double
            }
            let params = ViewportCountParams(
                p_user_id: userId,
                p_min_lon: viewport.minLon,
                p_min_lat: viewport.minLat,
                p_max_lon: viewport.maxLon,
                p_max_lat: viewport.maxLat
            )
            let response: Int = try await supabase.client
                .rpc("get_user_external_places_count", params: params)
                .execute()
                .value
            return response
        } else {
            let response: Int = try await supabase.client
                .rpc("get_user_external_places_count", params: ["p_user_id": userId])
                .execute()
                .value
            return response
        }
    }
    
    /// Get created places (my places) count - FAST! (count query only, no place data)
    func getNumberCreatedPlaces(forUserId userId: String) async throws -> Int {
        let response: Int = try await supabase.client
            .rpc("get_user_created_places_count", params: ["p_user_id": userId])
            .execute()
            .value
        
        return response
    }
    
    /// Get reviewed places count - FAST! (count query only, no place data)
    /// Returns count of distinct places reviewed by user (not total review count)
    func getNumberReviewedPlaces(forUserId userId: String) async throws -> Int {
        let response: Int = try await supabase.client
            .rpc("get_user_reviewed_places_count", params: ["p_user_id": userId])
            .execute()
            .value
        
        return response
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
            
            return lists
        } catch {
            print("❌ [Supabase] Error fetching place lists: \(error.localizedDescription)")
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
            
            return lists.first
        } catch {
            print("❌ [Supabase] Error fetching place list by ID: \(error)")
            throw error
        }
    }
    
    /// Fetch user's place lists without location sorting (fallback when location unavailable)
    /// Returns lists ordered by creation date (newest first) with place counts
    func fetchPlaceListsWithoutLocation(userId: String, page: Int = 1, pageSize: Int = 20) async throws -> [LightweightPlaceList] {
        // Nested struct to decode the count from Supabase's embedded resource syntax
        struct PlaceListItemCount: Codable {
            let count: Int
        }

        struct ListWithCount: Codable {
            let id: String
            let name: String
            let is_public: Bool?
            let image: String?
            let created_at: String?
            let updated_at: String?
            let average_location: String?
            let place_list_items: [PlaceListItemCount]
        }

        // Use a subquery to get place count for each list
        let response: [ListWithCount] = try await supabase.client
            .from("place_lists")
            .select("""
                id,
                name,
                is_public,
                image,
                created_at,
                updated_at,
                average_location::text,
                place_list_items(count)
            """)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: (page - 1) * pageSize, to: page * pageSize - 1)
            .execute()
            .value

        return response.map { record in
            LightweightPlaceList(
                list_id: record.id,
                name: record.name,
                is_public: record.is_public ?? false,
                image: record.image,
                created_at: record.created_at,
                updated_at: record.updated_at,
                distance_meters: nil,
                place_count: record.place_list_items.first?.count ?? 0,
                city: nil,
                average_location_raw: record.average_location
            )
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
            let average_location: String?
        }

        // Fetch matching lists from database
        let response: [SearchListRecord] = try await supabase.client
            .from("place_lists")
            .select("id, name, is_public, image, created_at, updated_at, average_location::text")
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
                city: nil,
                average_location_raw: record.average_location
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

        let records: [FollowingProfileRecord] = try await supabase.client
            .rpc("get_follower_profiles_paginated", params: params)
            .execute()
            .value

        return records.map { convertFollowingRecordToProfileData($0) }
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

        let records: [FollowingProfileRecord] = try await supabase.client
            .rpc("get_following_profiles_paginated", params: params)
            .execute()
            .value

        return records.map { convertFollowingRecordToProfileData($0) }
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
            fcmToken: record.fcm_token,
            instagramUsername: record.instagram_username,
            tiktokUsername: record.tiktok_username
        )
    }

    private func convertFollowingRecordToProfileData(_ record: FollowingProfileRecord) -> ProfileData {
        return ProfileData(
            id: record.id,
            firstName: record.first_name,
            lastName: record.last_name,
            email: record.email,
            profilePhotoURL: record.profile_photo_url.flatMap { URL(string: $0) },
            phoneNumber: record.phone_number ?? "",
            fullNameLower: record.full_name_lower ?? record.full_name.lowercased(),
            fullName: record.full_name,
            fcmToken: record.fcm_token,
            firebaseUid: nil,
            supabaseUid: record.supabase_uid,
            instagramUsername: record.instagram_username,
            tiktokUsername: record.tiktok_username
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
    
    /// Fetches user's external places, optionally filtered to a map viewport.
    func fetchUserExternalPlaces(userId: String, limit: Int = 8, offset: Int = 0, viewport: (minLon: Double, minLat: Double, maxLon: Double, maxLat: Double)? = nil) async throws -> [LightweightPlace] {
        if let viewport = viewport {
            struct ViewportParams: Encodable {
                let p_user_id: String
                let p_limit: Int
                let p_offset: Int
                let p_min_lon: Double
                let p_min_lat: Double
                let p_max_lon: Double
                let p_max_lat: Double
            }
            let params = ViewportParams(
                p_user_id: userId,
                p_limit: limit,
                p_offset: offset,
                p_min_lon: viewport.minLon,
                p_min_lat: viewport.minLat,
                p_max_lon: viewport.maxLon,
                p_max_lat: viewport.maxLat
            )
            let places: [LightweightPlace] = try await supabase.client
                .rpc("get_user_external_places", params: params)
                .execute()
                .value
            return places
        } else {
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
    let instagram_username: String?
    let tiktok_username: String?
}

/// Response type for following/followers RPC calls - handles nullable database fields
private struct FollowingProfileRecord: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let full_name: String
    let full_name_lower: String?  // Can be NULL for older users
    let email: String
    let phone_number: String?     // Can be NULL
    let profile_photo_url: String?
    let fcm_token: String?
    let created_at: String?       // Returned by DB but not needed
    let supabase_uid: String?
    let instagram_username: String?
    let tiktok_username: String?
}

/// Lightweight favorite place data for display
struct FavoritePlace: Codable, Identifiable, Equatable {
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
    /// Add a place to a list with tracking of who added it
    /// - Parameters:
    ///   - listId: The list to add the place to
    ///   - placeId: The place to add
    ///   - addedBy: The user ID of who is adding the place (for collaborative list attribution)
    func addPlaceToList(listId: String, placeId: String, addedBy: String) async throws {
        // Get the current MIN sort_order so new places go at the TOP (most recent first)
        // This ensures new places appear on page 1 immediately (query uses ORDER BY sort_order ASC)
        let minOrderResponse = try await supabase.client
            .from("place_list_items")
            .select("sort_order")
            .eq("list_id", value: listId)
            .order("sort_order", ascending: true)
            .limit(1)
            .execute()

        let minOrder = (try? JSONDecoder().decode([SortOrder].self, from: minOrderResponse.data).first?.sort_order) ?? 1
        let nextOrder = minOrder - 1  // New places get lowest sort_order (appear first)
        
        // Create insert struct with added_by for attribution
        struct PlaceListItem: Encodable {
            let list_id: String
            let place_id: String
            let sort_order: Int
            let added_by: String
        }
        
        let newItem = PlaceListItem(
            list_id: listId,
            place_id: placeId,
            sort_order: nextOrder,
            added_by: addedBy
        )
        
        // Insert the new item
        try await supabase.client
            .from("place_list_items")
            .insert(newItem)
            .execute()
        
        print("✅ [Supabase] Added place \(placeId) to list \(listId) by user \(addedBy) at position \(nextOrder)")
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
    
    // MARK: - External Place Deletion
    
    /// Deletes all external_places records for a user and place combination
    /// Single Responsibility: Execute Supabase delete operation for external places
    /// - Parameters:
    ///   - userId: The user's ID
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

    // MARK: - External Place Update

    /// Updates the place_id for an external_places record (TikTok place correction)
    /// Single Responsibility: Execute Supabase update operation for external place association
    /// - Parameters:
    ///   - externalPlaceId: The external_places row ID to update
    ///   - newPlaceId: The new place ID to associate with
    ///   - userId: The user's ID for verification
    /// - Throws: Database errors if update fails
    func updateExternalPlaceAssociation(externalPlaceId: String, newPlaceId: String, userId: String) async throws {
        try await supabase.client
            .from("external_places")
            .update(["place_id": newPlaceId])
            .eq("id", value: externalPlaceId)
            .eq("user_id", value: userId)
            .execute()

        print("✅ [SupabaseUserService] Updated external place \(externalPlaceId) to place \(newPlaceId)")
    }

    // MARK: - External Place Insert

    /// Inserts a new external_places record for a TikTok place assignment.
    func insertExternalPlace(userId: String, placeId: String, url: String) async throws {
        let id = UUID().uuidString
        try await supabase.client
            .from("external_places")
            .insert([
                "id": id,
                "user_id": userId,
                "place_id": placeId,
                "url": url,
                "source": "tiktok"
            ])
            .execute()

        print("✅ [SupabaseUserService] Inserted external place for user \(userId), place \(placeId)")
    }
}

