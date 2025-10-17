import Foundation
import Supabase

// MARK: - Response Models for External Places
struct ExternalPlaceResponse: Codable {
    let id: String
    let userId: String
    let placeId: String
    let source: String
    let tiktokVideos: AnyCodable?
    let addedAt: Date
    let places: ExternalPlaceData?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case placeId = "place_id"
        case source
        case tiktokVideos = "tiktok_videos"
        case addedAt = "added_at"
        case places
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.placeId = try container.decode(String.self, forKey: .placeId)
        self.source = try container.decode(String.self, forKey: .source)
        self.addedAt = try container.decode(Date.self, forKey: .addedAt)
        self.places = try container.decodeIfPresent(ExternalPlaceData.self, forKey: .places)
        self.tiktokVideos = try container.decodeIfPresent(AnyCodable.self, forKey: .tiktokVideos)
    }
    
    // Manual initializer for creating instances programmatically
    init(id: String, userId: String, placeId: String, source: String, tiktokVideos: AnyCodable?, addedAt: Date, places: ExternalPlaceData?) {
        self.id = id
        self.userId = userId
        self.placeId = placeId
        self.source = source
        self.tiktokVideos = tiktokVideos
        self.addedAt = addedAt
        self.places = places
    }
}

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

struct ExternalPlaceData: Codable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
}

struct ExternalPlaceBasicResponse: Codable {
    let id: String
    let userId: String
    let placeId: String
    let source: String
    let tiktokVideos: AnyCodable?
    let addedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case placeId = "place_id"
        case source
        case tiktokVideos = "tiktok_videos"
        case addedAt = "added_at"
    }
}

struct PlaceBasicResponse: Codable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
}

struct ExternalPlaceDirectResponse: Codable {
    let id: String
    let userId: String
    let placeId: String?
    let name: String?
    let address: String?
    let coordinates: AnyCodable? // PostGIS geometry
    let source: String?
    let tiktokVideos: AnyCodable? // JSONB array
    let addedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case placeId = "place_id"
        case name
        case address
        case coordinates
        case source
        case tiktokVideos = "tiktok_videos"
        case addedAt = "added_at"
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
        print("🔄 [UserService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchUser(userId: userId, completion: completion)
        }
    }

    func fetchFriends(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [UserService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchFriends(userId: userId, completion: completion)
            }
    }

    func fetchProfiles(for userIds: [String], completion: @escaping ([User]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [UserService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchProfiles(for: userIds, completion: completion)
        }
    }

    func fetchFollowingProfiles(for userId: String, completion: @escaping ([User]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [UserService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchFollowingProfiles(for: userId, completion: completion)
        }
    }
    
    func updateFCMToken(userId: String, token: String, completion: @escaping (Error?) -> Void) {
        // ⚠️ NOW UPDATING IN SUPABASE, NOT FIRESTORE
        print("🔄 [UserService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.updateFCMToken(userId: userId, token: token, completion: completion)
        }
    }
    
    func deleteAccount(userId: String, completion: @escaping (Error?) -> Void) {
        print("🔄 [UserService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.deleteAccount(userId: userId, completion: completion)
        }
    }
    
    // Placeholder methods for compatibility
    func fetchFollowerProfiles(for userId: String, completion: @escaping ([User]?, Error?) -> Void) {
        print("⚠️ [UserService] fetchFollowerProfiles not fully implemented")
        completion([], nil)
    }
    
    func fetchUserById(userId: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
        // Fetch user profile from Supabase users table
        print("🔄 [UserService] Fetching user profile from Supabase: \(userId)")
        Task { @MainActor in
            do {
                let response: [ProfileData] = try await SupabaseManager.shared.database
                    .from("users")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value

                guard let profileData = response.first else {
                    throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
                }
                print("✅ [UserService] Found existing user profile: \(profileData.firstName) \(profileData.lastName)")
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
        print("🔄 [UserService] Fetching user profile async from Supabase: \(userId)")

        do {
            // First try to fetch by id (works for Firebase UIDs and new Supabase users)
            let profile: ProfileData = try await SupabaseManager.shared.database
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            print("✅ [UserService] Found user profile: \(profile.firstName) \(profile.lastName)")
            return profile

        } catch {
            print("🔄 [UserService] User not found by id, trying supabase_uid: \(userId)")

            // If not found by id, try by supabase_uid (for Supabase auth UIDs)
            do {
                let profile: ProfileData = try await SupabaseManager.shared.database
                    .from("users")
                    .select()
                    .eq("supabase_uid", value: userId)
                    .single()
                    .execute()
                    .value

                print("✅ [UserService] Found user profile by supabase_uid: \(profile.firstName) \(profile.lastName)")
                return profile

                } catch {
                print("❌ [UserService] User profile not found by id or supabase_uid: \(userId)")
                throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
            }
        }
    }

    func fetchUserBySupabaseUid(supabaseUid: String, completion: @escaping (Result<ProfileData, Error>) -> Void) {
        print("🔄 [UserService] Fetching user profile by Supabase auth UID: \(supabaseUid)")
        Task { @MainActor in
            do {
                let profile = try await fetchUserBySupabaseUid(supabaseUid: supabaseUid)
                completion(.success(profile))
        } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchUserBySupabaseUid(supabaseUid: String) async throws -> ProfileData {
        print("🔄 [UserService] Fetching user profile by Supabase auth UID: \(supabaseUid)")

        do {
            let profile: ProfileData = try await SupabaseManager.shared.database
                .from("users")
                .select()
                .eq("supabase_uid", value: supabaseUid)
                .single()
                .execute()
                .value

            print("✅ [UserService] Found user profile: \(profile.firstName) \(profile.lastName)")
            return profile

        } catch {
            print("❌ [UserService] User profile not found by supabase_uid: \(supabaseUid)")
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
    }
    
    func fetchUserExternalPlaces(userId: String, completion: @escaping (Result<[ExternalPlace], Error>) -> Void) {
        print("🔄 [UserService] Fetching external places for user: \(userId)")
        Task {
            do {
                let externalPlaces = try await fetchUserExternalPlaces(userId: userId)
                completion(.success(externalPlaces))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func fetchUserExternalPlaces(userId: String) async throws -> [ExternalPlace] {
        do {
            // Fetch external places for the specific user
            let externalPlacesResponse: [ExternalPlaceDirectResponse] = try await SupabaseManager.shared.database
                .from("external_places")
                .select("""
                    id,
                    user_id,
                    place_id,
                    name,
                    address,
                    coordinates,
                    source,
                    tiktok_videos,
                    added_at
                """)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            print("✅ [UserService] Found \(externalPlacesResponse.count) external places for user")
            
            // If no external places found, try alternative user ID formats
            if externalPlacesResponse.isEmpty {
                let alternativeUserIds = [
                    userId.lowercased(),
                    userId.uppercased(),
                    userId.replacingOccurrences(of: "-", with: ""),
                    userId.replacingOccurrences(of: "-", with: "").lowercased()
                ].filter { $0 != userId }
                
                for altUserId in alternativeUserIds {
                    let altResponse: [ExternalPlaceDirectResponse] = try await SupabaseManager.shared.database
                        .from("external_places")
                        .select("""
                            id,
                            user_id,
                            place_id,
                            name,
                            address,
                            coordinates,
                            source,
                            tiktok_videos,
                            added_at
                        """)
                        .eq("user_id", value: altUserId)
                        .execute()
                        .value
                    
                    if !altResponse.isEmpty {
                        print("✅ [UserService] Found \(altResponse.count) external places with alternative user_id")
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
    
    // Helper method to process external places response
    private func processExternalPlacesResponse(_ externalPlacesResponse: [ExternalPlaceBasicResponse]) async throws -> [ExternalPlace] {
        // Get all place IDs from external places
        let placeIds = externalPlacesResponse.map { $0.placeId }
        print("📍 [UserService] Fetching details for \(placeIds.count) places: \(placeIds)")
        
        // Fetch place details separately
        let placesResponse: [PlaceBasicResponse] = try await SupabaseManager.shared.database
            .from("places")
            .select("""
                id,
                name,
                address,
                latitude,
                longitude
            """)
            .in("id", values: placeIds)
            .execute()
            .value
        
        print("🏢 [UserService] Found \(placesResponse.count) place details")
        
        // Create a dictionary for quick lookup
        let placesDict = Dictionary(uniqueKeysWithValues: placesResponse.map { ($0.id, $0) })
        
        // Combine external places with place details
        let response = externalPlacesResponse.compactMap { externalPlace -> ExternalPlaceResponse? in
            guard let place = placesDict[externalPlace.placeId] else {
                print("⚠️ [UserService] No place details found for place ID: \(externalPlace.placeId)")
                return nil
            }
            
            return ExternalPlaceResponse(
                id: externalPlace.id,
                userId: externalPlace.userId,
                placeId: externalPlace.placeId,
                source: externalPlace.source,
                tiktokVideos: externalPlace.tiktokVideos,
                addedAt: externalPlace.addedAt,
                places: ExternalPlaceData(
                    id: place.id,
                    name: place.name,
                    address: place.address,
                    latitude: place.latitude,
                    longitude: place.longitude
                )
            )
        }
        
        print("📊 [UserService] Raw response count: \(response.count)")
        print("📋 [UserService] Raw response data: \(response)")
        
        // Convert to ExternalPlace format
        let externalPlaces = response.compactMap { response -> ExternalPlace? in
            print("🔄 [UserService] Processing response item: \(response.id)")
            print("📍 [UserService] Place data: \(response.places?.name ?? "nil")")
            print("🎥 [UserService] TikTok videos data: \(response.tiktokVideos?.value ?? "nil")")
            
            guard let place = response.places else { 
                print("❌ [UserService] No place data for response: \(response.id)")
                return nil 
            }
            
            let coordinates = ExternalPlaceCoordinates(
                latitude: place.latitude ?? 0.0,
                longitude: place.longitude ?? 0.0
            )
            
            // Parse TikTok videos from JSONB
            var tiktokVideos: [ExternalTikTokVideo] = []
            if let videosData = response.tiktokVideos?.value {
                print("🎬 [UserService] Parsing TikTok videos data...")
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: videosData)
                    tiktokVideos = try JSONDecoder().decode([ExternalTikTokVideo].self, from: jsonData)
                    print("✅ [UserService] Successfully parsed \(tiktokVideos.count) TikTok videos")
                } catch {
                    print("⚠️ [UserService] Error parsing TikTok videos: \(error)")
                    print("🔍 [UserService] Videos data was: \(videosData)")
                }
            } else {
                print("ℹ️ [UserService] No TikTok videos data for place: \(place.name)")
            }
            
            let externalPlace = ExternalPlace(
                id: response.id,
                addedAt: response.addedAt,
                address: place.address ?? "",
                coordinates: coordinates,
                name: place.name,
                placeId: place.id,
                source: response.source,
                tiktokVideos: tiktokVideos
            )
            
            print("✅ [UserService] Created ExternalPlace: \(externalPlace.name) with \(externalPlace.tiktokVideos.count) videos")
            return externalPlace
        }
        
        print("✅ [UserService] Successfully fetched \(externalPlaces.count) external places")
        for place in externalPlaces {
            print("📍 [UserService] - \(place.name) (\(place.placeId)) with \(place.tiktokVideos.count) videos")
        }
        return externalPlaces
    }
    
    // Helper method to process direct external places response (from your table structure)
    private func processDirectExternalPlacesResponse(_ externalPlacesResponse: [ExternalPlaceDirectResponse]) async throws -> [ExternalPlace] {
        let externalPlaces = externalPlacesResponse.compactMap { response -> ExternalPlace? in
            // Extract coordinates from PostGIS geometry
            var coordinates = ExternalPlaceCoordinates(latitude: 0.0, longitude: 0.0)
            if let coordsData = response.coordinates?.value {
                // PostGIS geometry format - might need special parsing
                // For now, we'll use default coordinates
            }
            
            // Parse TikTok videos from JSONB array
            var tiktokVideos: [ExternalTikTokVideo] = []
            if let videosData = response.tiktokVideos?.value {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: videosData)
                    tiktokVideos = try JSONDecoder().decode([ExternalTikTokVideo].self, from: jsonData)
                } catch {
                    print("⚠️ [UserService] Error parsing TikTok videos: \(error)")
                }
            }
            
            let externalPlace = ExternalPlace(
                id: response.id,
                addedAt: response.addedAt ?? Date(),
                address: response.address ?? "",
                coordinates: coordinates,
                name: response.name ?? "Unknown Place",
                placeId: response.placeId ?? response.id, // Use place_id if available, otherwise use id
                source: response.source ?? "unknown",
                tiktokVideos: tiktokVideos
            )
            
            return externalPlace
        }
        
        print("✅ [UserService] Successfully processed \(externalPlaces.count) external places")
        return externalPlaces
    }
    
    // LAZY Loading - Only load when user clicks!
    func fetchFollowingProfilesData(for userId: String, completion: @escaping (Result<[ProfileData], Error>) -> Void) {
        Task { @MainActor in
            do {
                let profiles = try await supabase.fetchFollowingProfilesData(for: userId)
                completion(.success(profiles))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func fetchFollowingProfilesData(for userId: String) async throws -> [ProfileData] {
        return try await supabase.fetchFollowingProfilesData(for: userId, limit: nil, offset: 0)
    }
    
    // Paginated version for progressive loading
    func fetchFollowingProfilesData(for userId: String, limit: Int, offset: Int) async throws -> [ProfileData] {
        return try await supabase.fetchFollowingProfilesData(for: userId, limit: limit, offset: offset)
    }
    
    func fetchFollowerProfilesData(for userId: String, completion: @escaping (Result<[ProfileData], Error>) -> Void) {
        Task { @MainActor in
            do {
                let profiles = try await supabase.fetchFollowerProfilesData(for: userId)
                completion(.success(profiles))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func fetchFollowerProfilesData(for userId: String) async throws -> [ProfileData] {
        return try await supabase.fetchFollowerProfilesData(for: userId, limit: nil, offset: 0)
    }
    
    // Paginated version for progressive loading
    func fetchFollowerProfilesData(for userId: String, limit: Int, offset: Int) async throws -> [ProfileData] {
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
    
    func isFollowingUser(followerId: String, followingId: String, completion: @escaping (Bool) -> Void) {
        print("⚠️ [UserService] isFollowingUser not fully implemented")
        completion(false)
    }
    
    func followUser(followerId: String, followingId: String, completion: @escaping (Bool, Error?) -> Void) {
        print("⚠️ [UserService] followUser not fully implemented")
                            completion(true, nil)
    }
    
    func unfollowUser(followerId: String, followingId: String, completion: @escaping (Bool, Error?) -> Void) {
        print("⚠️ [UserService] unfollowUser not fully implemented")
                completion(true, nil)
    }
    
    func addOrUpdateMapPlace(userId: String, place: DetailPlace, completion: @escaping (Error?) -> Void) {
        print("⚠️ [UserService] addOrUpdateMapPlace not fully implemented")
        completion(nil)
    }

    func fetchUserLists(userId: String, completion: @escaping ([PlaceList]?, Error?) -> Void) {
        print("⚠️ [UserService] fetchUserLists not fully implemented")
                    completion([], nil)
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
                let _ = try await SupabaseManager.shared.database
                    .from("users")
                    .insert(profileData)
                    .execute()

                print("✅ [UserService] Successfully saved user profile to Supabase")
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
        print("⚠️ [UserService] searchUsers not fully implemented")
        completion([], nil)
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
        print("⚠️ [UserService] saveExternalPlace not fully implemented")
        completion(true, nil)
    }
    
    func deleteTikTokPlace(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [UserService] deleteTikTokPlace not fully implemented")
        completion(nil)
    }
    
    func deleteUserAccount(userId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [UserService] deleteUserAccount not fully implemented")
        completion(nil)
    }
} 
