import Foundation
import Supabase

// MARK: - Response Models for External Places

// Helper struct to handle Any type in Codable
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

struct PlaceData: Codable {
    let name: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
}

struct ExternalPlaceDirectResponse: Codable {
    let id: String
    let userId: String
    let placeId: String?
    let source: String?
    let url: String? // TikTok video URL
    let addedAt: Date?
    let places: PlaceData? // Joined from places table
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case placeId = "place_id"
        case source
        case url
        case addedAt = "added_at"
        case places
    }
}

/// Legacy UserService - now delegates all calls to SupabaseUserService
/// This wrapper exists for backward compatibility with existing ViewModels
class UserService: ObservableObject {
    static let shared = UserService()
    private let supabase = SupabaseUserService.shared // All data comes from Supabase
    
    private init() {
        // UserService is a compatibility wrapper - all data from Supabase
    }

    func fetchUser(userId: String, completion: @escaping (User?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        Task { @MainActor in
            await supabase.fetchUser(userId: userId, completion: completion)
        }
    }

    func fetchFriends(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        Task { @MainActor in
            await supabase.fetchFriends(userId: userId, completion: completion)
            }
    }

    func fetchProfiles(for userIds: [String], completion: @escaping ([User]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        Task { @MainActor in
            await supabase.fetchProfiles(for: userIds, completion: completion)
        }
    }

    func fetchFollowingProfiles(for userId: String, completion: @escaping ([User]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        Task { @MainActor in
            await supabase.fetchFollowingProfiles(for: userId, completion: completion)
        }
    }
    
    func updateFCMToken(userId: String, token: String, completion: @escaping (Error?) -> Void) {
        // ⚠️ NOW UPDATING IN SUPABASE, NOT FIRESTORE
        Task { @MainActor in
            await supabase.updateFCMToken(userId: userId, token: token, completion: completion)
        }
    }
    
    func deleteAccount(userId: String, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            await supabase.deleteAccount(userId: userId, completion: completion)
        }
    }
    
    // Placeholder methods for compatibility
    func fetchFollowerProfiles(for userId: String, completion: @escaping ([User]?, Error?) -> Void) {
        completion([], nil)
    }
    
    func fetchUserById(userId: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
        Task { @MainActor in
            do {
            let profileData: ProfileData = try await SupabaseManager.shared.client
                .from("users")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value

                completion(.success(profileData))
            } catch let error as DecodingError {
                print("❌ [UserService] Decoding error: \(error.localizedDescription)")
                completion(.failure(error))
            } catch {
                print("ℹ️ [UserService] User profile not found (404): \(error.localizedDescription)")
                // Return a specific error for "not found" so LoginViewModel knows to create profile
                let notFoundError = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
                completion(.failure(notFoundError))
            }
        }
    }
    
    func fetchUserById(userId: String) async throws -> ProfileData {
        do {
            // First try to fetch by id (works for UIDs and new Supabase users)
            let profile: ProfileData = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            return profile

        } catch {
            // If not found by id, try by supabase_uid (for Supabase auth UIDs)
            do {
                let profile: ProfileData = try await SupabaseManager.shared.client
                    .from("users")
                    .select()
                    .eq("supabase_uid", value: userId)
                    .single()
                    .execute()
                    .value

                return profile

                } catch {
                print("❌ [UserService] User profile not found by id or supabase_uid: \(userId)")
                throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
            }
        }
    }

    func fetchUserBySupabaseUid(supabaseUid: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
        Task {
            do {
                let profile = try await fetchUserBySupabaseUid(supabaseUid: supabaseUid)
                await MainActor.run {
                    completion(.success(profile))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func fetchUserBySupabaseUid(supabaseUid: String) async throws -> ProfileData {
        do {
            let profile: ProfileData = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("supabase_uid", value: supabaseUid)
                .single()
                .execute()
                .value

            return profile

        } catch {
            print("❌ [UserService] User profile not found by supabase_uid: \(supabaseUid)")
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
    }
    
    /// Fetch external places for a specific place ID and user
    /// Returns tuples of (external_place_id, url) for TikTok videos
    func fetchExternalPlaceURLs(placeId: String, userId: String) async throws -> [(id: String, url: String)] {
        do {
            let response: [ExternalPlaceDirectResponse] = try await SupabaseManager.shared.client
                .from("external_places")
                .select("""
                    id,
                    user_id,
                    place_id,
                    source,
                    url,
                    added_at
                """)
                .eq("place_id", value: placeId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            // Extract (id, url) pairs and filter out empty URLs
            let urlPairs = response.compactMap { response -> (id: String, url: String)? in
                guard let url = response.url, !url.isEmpty else {
                    return nil
                }
                return (id: response.id, url: url)
            }
            return urlPairs
        } catch {
            print("❌ [UserService] Error fetching external place URLs: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch ALL external place URLs for a place (from all users)
    /// Returns tuples of (external_place_id, url, user_id) for ownership tracking
    func fetchAllExternalPlaceURLs(placeId: String) async throws -> [(id: String, url: String, userId: String)] {
        do {
            let response: [ExternalPlaceDirectResponse] = try await SupabaseManager.shared.client
                .from("external_places")
                .select("""
                    id,
                    user_id,
                    place_id,
                    source,
                    url,
                    added_at
                """)
                .eq("place_id", value: placeId)
                .execute()
                .value
            
            // Extract (id, url, userId) tuples and filter out empty URLs
            let urlTuples = response.compactMap { response -> (id: String, url: String, userId: String)? in
                guard let url = response.url, !url.isEmpty else {
                    return nil
                }
                return (id: response.id, url: url, userId: response.userId)
            }
            return urlTuples
        } catch {
            print("❌ [UserService] Error fetching all external place URLs: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch all external places for a user (full objects with place data joined)
    /// Use fetchUserExternalPlaces(userId:limit:offset:) for paginated lightweight results
    func fetchAllUserExternalPlaces(userId: String) async throws -> [ExternalPlace] {
        do {
            // Fetch external places for the specific user, joining with places table for name/address/coordinates
            let externalPlacesResponse: [ExternalPlaceDirectResponse] = try await SupabaseManager.shared.client
                .from("external_places")
                .select("""
                    id,
                    user_id,
                    place_id,
                    source,
                    url,
                    added_at,
                    places:place_id (
                        name,
                        address,
                        latitude,
                        longitude
                    )
                """)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            // If no external places found, try alternative user ID formats
            if externalPlacesResponse.isEmpty {
                let alternativeUserIds = [
                    userId.lowercased(),
                    userId.uppercased(),
                    userId.replacingOccurrences(of: "-", with: ""),
                    userId.replacingOccurrences(of: "-", with: "").lowercased()
                ].filter { $0 != userId }
                
                for altUserId in alternativeUserIds {
                    let altResponse: [ExternalPlaceDirectResponse] = try await SupabaseManager.shared.client
                        .from("external_places")
                        .select("""
                            id,
                            user_id,
                            place_id,
                            source,
                            url,
                            added_at,
                            places:place_id (
                                name,
                                address,
                                latitude,
                                longitude
                            )
                        """)
                        .eq("user_id", value: altUserId)
                        .execute()
                        .value
                    
                    if !altResponse.isEmpty {
                        return try await processDirectExternalPlacesResponse(altResponse)
                    }
                }
                
                return []
            }
            
            // Process the external places response
            return try await processDirectExternalPlacesResponse(externalPlacesResponse)
            
        } catch {
            print("❌ [UserService] Error fetching external places: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper method to process direct external places response (from your table structure)
    private func processDirectExternalPlacesResponse(_ externalPlacesResponse: [ExternalPlaceDirectResponse]) async throws -> [ExternalPlace] {
        let externalPlaces = externalPlacesResponse.compactMap { response -> ExternalPlace? in
            // Use joined place data from places table
            guard let placeData = response.places else {
                print("⚠️ [UserService] No place data found for external place \(response.id)")
                return nil
            }
            
            let coordinates = ExternalPlaceCoordinates(
                latitude: placeData.latitude ?? 0.0,
                longitude: placeData.longitude ?? 0.0
            )
            
            let externalPlace = ExternalPlace(
                id: response.id,
                addedAt: response.addedAt ?? Date(),
                address: placeData.address ?? "",
                coordinates: coordinates,
                name: placeData.name ?? "Unknown Place",
                placeId: response.placeId ?? response.id,
                source: response.source ?? "unknown",
                url: response.url // Store URL only - TikTok metadata fetched on-demand via oEmbed
            )
            
            return externalPlace
        }
        
        return externalPlaces
    }
    
    func fetchFollowingProfilesData(for userId: String, limit: Int, offset: Int = 0) async throws -> [ProfileData] {
        return try await supabase.fetchFollowingProfilesData(for: userId, limit: limit, offset: offset)
    }
    
    func fetchFollowerProfilesData(for userId: String, limit: Int, offset: Int = 0) async throws -> [ProfileData] {
        return try await supabase.fetchFollowerProfilesData(for: userId, limit: limit, offset: offset)
    }
    
    // COUNT ONLY - Super fast! (~20-50ms)
    func getNumberFollowers(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        Task { @MainActor in
            do {
                let count = try await supabase.getNumberFollowers(forUserId: userId)
                completion(count, nil)
            } catch {
                completion(0, error)
            }
        }
    }
    
    func getNumberFollowers(forUserId userId: String) async throws -> Int {
        return try await supabase.getNumberFollowers(forUserId: userId)
    }
    
    // COUNT ONLY - Super fast! (~20-50ms)
    func getNumberFollowing(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        Task { @MainActor in
            do {
                let count = try await supabase.getNumberFollowing(forUserId: userId)
                completion(count, nil)
            } catch {
                completion(0, error)
            }
        }
    }
    
    func getNumberFollowing(forUserId userId: String) async throws -> Int {
        return try await supabase.getNumberFollowing(forUserId: userId)
    }
    
    // COUNT ONLY - Super fast! (~20-50ms)
    func getNumberMyPlaces(forUserId userId: String) async throws -> Int {
        return try await supabase.getNumberMyPlaces(forUserId: userId)
    }
    
    // COUNT ONLY - Super fast! (~20-50ms)
    func getTotalListCount(forUserId userId: String) async throws -> Int {
        return try await supabase.getTotalListCount(forUserId: userId)
    }
    
    /// Fetch user favorites using optimized SQL function
    func fetchUserFavorites(userId: String) async throws -> [FavoritePlace] {
        return try await supabase.fetchUserFavorites(userId: userId)
    }
    
    /// Fetch user's place lists sorted by proximity to user's location
    func fetchPlaceListsByProximity(userId: String, userLatitude: Double, userLongitude: Double, page: Int = 1, pageSize: Int = 10) async throws -> [LightweightPlaceList] {
        return try await supabase.fetchPlaceListsByProximity(userId: userId, userLatitude: userLatitude, userLongitude: userLongitude, page: page, pageSize: pageSize)
    }
    
    /// Fetch a single place list by ID (for deep link navigation)
    func fetchPlaceListById(listId: String) async throws -> LightweightPlaceList? {
        return try await supabase.fetchPlaceListById(listId: listId)
    }
    
    /// Search place lists by name with pagination
    func searchPlaceLists(userId: String, query: String, page: Int = 1, pageSize: Int = 20) async throws -> [LightweightPlaceList] {
        return try await supabase.searchPlaceLists(userId: userId, query: query, page: page, pageSize: pageSize)
    }
    
    /// Fetch places within a place list with pagination
    func fetchPlacesForPlaceList(listId: String, page: Int = 1, pageSize: Int = 6) async throws -> [LightweightPlace] {
        return try await supabase.fetchPlacesForPlaceList(listId: listId, page: page, pageSize: pageSize)
    }
    
    /// Fetch user's created places (lightweight data for tiles, paginated)
    func fetchUserCreatedPlaces(userId: String, limit: Int = 8, offset: Int = 0) async throws -> [LightweightPlace] {
        return try await supabase.fetchUserCreatedPlaces(userId: userId, limit: limit, offset: offset)
    }
    
    /// Fetch user's external places (TikTok places, lightweight data for tiles, paginated)
    func fetchUserExternalPlaces(userId: String, limit: Int = 8, offset: Int = 0) async throws -> [LightweightPlace] {
        return try await supabase.fetchUserExternalPlaces(userId: userId, limit: limit, offset: offset)
    }
    
    /// Fetch user's reviewed places (lightweight data for tiles, paginated - server-side)
    func fetchUserReviewedPlaces(userId: String, limit: Int = 8, offset: Int = 0) async throws -> [LightweightPlace] {
        return try await supabase.fetchUserReviewedPlaces(userId: userId, limit: limit, offset: offset)
    }

    /// ✅ NEW: Fetch following user IDs only (not full profiles) - SUPER FAST!
    func fetchFollowingUserIds(userId: String) async throws -> [String] {
        return try await supabase.fetchFollowingUserIds(userId: userId)
    }
    
    func isFollowingUser(followerId: String, followingId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let isFollowing = try await supabase.isFollowingUser(followerId: followerId, followingId: followingId)
                completion(isFollowing)
            } catch {
                print("❌ [UserService] Error checking follow status: \(error)")
                completion(false)
            }
        }
    }
    
    func followUser(followerId: String, followingId: String, completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                try await supabase.followUser(followerId: followerId, followingId: followingId)
                completion(true, nil)
            } catch {
                print("❌ [UserService] Error following user: \(error)")
                completion(false, error)
            }
        }
    }
    
    func unfollowUser(followerId: String, followingId: String, completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                try await supabase.unfollowUser(followerId: followerId, followingId: followingId)
                completion(true, nil)
            } catch {
                print("❌ [UserService] Error unfollowing user: \(error)")
                completion(false, error)
            }
        }
    }
    
    func addOrUpdateMapPlace(userId: String, place: DetailPlace, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func fetchFriendsReviews(userId: String, completion: @escaping ([ReviewProtocol]?, Error?) -> Void) {
        // fetchFriendsReviews not fully implemented
                    completion([], nil)
    }
    
    func saveUserProfile(uid: String, profileData: ProfileData, completion: @escaping (Error?) -> Void) {
        // Save user profile to Supabase users table
        print("💾 [UserService] Saving user profile to Supabase: \(profileData.firstName) \(profileData.lastName)")
        Task { @MainActor in
            do {
                let _ = try await SupabaseManager.shared.client
                    .from("users")
                    .insert(profileData)
                    .execute()

                completion(nil)
            } catch {
                print("❌ [UserService] Error saving user profile: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func addProfileFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [UserService] addProfileFavorite not fully implemented")
        completion(nil)
    }
    
    func removeProfileFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [UserService] removeProfileFavorite not fully implemented")
        completion(nil)
    }
    
    func searchUsers(query: String, completion: @escaping ([User]?, Error?) -> Void) {
        Task { @MainActor in
            await supabase.searchUsers(query: query, completion: completion)
        }
    }
    
    func savePlaceNote(note: PlaceNote, completion: @escaping (Bool, Error?) -> Void) {
        print("⚠️ [UserService] savePlaceNote not fully implemented")
        completion(true, nil)
    }
    
    func fetchPlaceNote(userId: String, placeId: String, completion: @escaping (PlaceNote?, Error?) -> Void) {
        print("⚠️ [UserService] fetchPlaceNote not fully implemented")
        completion(nil, nil)
    }
    
    func deletePlaceNote(userId: String, placeId: String, completion: @escaping (Bool, Error?) -> Void) {
        print("⚠️ [UserService] deletePlaceNote not fully implemented")
        completion(true, nil)
    }
    
    func saveTikTokPlaceFlag(flag: TikTokPlaceFlag, completion: @escaping (Bool, Error?) -> Void) {
        print("⚠️ [UserService] saveTikTokPlaceFlag not fully implemented")
        completion(true, nil)
    }
    
    func hasUserFlaggedPlace(userId: String, placeId: String, completion: @escaping (TikTokPlaceFlag?, Error?) -> Void) {
        print("⚠️ [UserService] hasUserFlaggedPlace not fully implemented")
        completion(nil, nil)
    }
    
    func deleteTikTokPlaceFlag(userId: String, placeId: String, completion: @escaping (Bool, Error?) -> Void) {
        print("⚠️ [UserService] deleteTikTokPlaceFlag not fully implemented")
        completion(true, nil)
    }
    
    func saveExternalPlace(externalPlace: ExternalPlace, completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                // Get current user ID - use auth UID (should match users.id after migration)
                guard let userId = await SupabaseAuthService.shared.currentUserId else {
                    await MainActor.run {
                        completion(false, NSError(domain: "UserService", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "User not logged in"
                        ]))
                    }
                    return
                }
                
                print("💾 [UserService] Saving external place with user ID: \(userId)")
                
                // Save to Supabase
                try await SupabaseUserService.shared.saveExternalPlace(
                    externalPlace: externalPlace,
                    userId: userId
                )
                
                await MainActor.run {
                    completion(true, nil)
                }
            } catch {
                print("❌ [UserService] Error saving external place: \(error.localizedDescription)")
                await MainActor.run {
                    completion(false, error)
                }
            }
        }
    }
    
    func deleteTikTokPlace(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [UserService] deleteTikTokPlace not fully implemented")
        completion(nil)
    }
    
    func deleteUserAccount(userId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [UserService] deleteUserAccount not fully implemented")
        completion(nil)
    }
    
    // MARK: - Place List Management
    
    func addPlaceToList(listId: String, placeId: String) async throws {
        try await supabase.addPlaceToList(listId: listId, placeId: placeId)
    }
    
    func removePlaceFromList(listId: String, placeId: String) async throws {
        try await supabase.removePlaceFromList(listId: listId, placeId: placeId)
    }
    
    func checkPlaceInList(listId: String, placeId: String) async throws -> Bool {
        return try await supabase.checkPlaceInList(listId: listId, placeId: placeId)
    }
    
    // MARK: - Place Savers
    
    /// Fetches all users who have saved a specific place (via favorites, lists, TikToks, or reviews)
    /// - Parameters:
    ///   - placeId: The ID of the place to check
    ///   - requestingUserId: Optional - filters to only show the user + users they follow
    /// - Returns: Array of PlaceSaverProfile containing user info
    func fetchPlaceSavers(placeId: String, requestingUserId: String?) async throws -> [PlaceSaverProfile] {
        // Build parameters for RPC call (database uses TEXT type)
        var params: [String: String] = ["p_place_id": placeId]
        if let requestingId = requestingUserId {
            params["p_requesting_user_id"] = requestingId
        }
        
        let response: [PlaceSaverProfile] = try await SupabaseManager.shared.client
            .rpc("get_place_savers", params: params)
            .execute()
            .value
        
        print("✅ [UserService] Fetched \(response.count) savers for place \(placeId.prefix(8))...")
        return response
    }
}

// MARK: - Place Saver Response Model

/// Response model for get_place_savers database function
struct PlaceSaverProfile: Codable, Identifiable {
    let userId: String
    let fullName: String?
    let profilePhotoUrl: String?
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case profilePhotoUrl = "profile_photo_url"
    }
    
    /// Convert to ProfileData for compatibility with existing UI components
    func toProfileData() -> ProfileData {
        // Convert String URL to URL type
        let photoURL: URL? = profilePhotoUrl.flatMap { URL(string: $0) }
        
        return ProfileData(
            id: userId,
            firstName: fullName?.components(separatedBy: " ").first ?? "",
            lastName: fullName?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? "",
            email: "",
            profilePhotoURL: photoURL,
            phoneNumber: "",
            fullNameLower: fullName?.lowercased() ?? "",
            fullName: fullName ?? "Unknown",
            fcmToken: nil,
            firebaseUid: nil,
            supabaseUid: nil
        )
    }
} 
