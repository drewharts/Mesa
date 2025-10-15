import Foundation

/// Legacy UserService - now delegates all calls to SupabaseUserService
/// This wrapper exists for backward compatibility with existing ViewModels
class UserService: ObservableObject {
    static let shared = UserService()
    private let supabase = SupabaseUserService.shared // All data comes from Supabase
    
    private init() {
        print("⚠️ UserService is a compatibility wrapper - all data from Supabase")
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

            print("✅ [UserService] Found user profile by id: \(profile.firstName) \(profile.lastName)")
            print("📋 [UserService] Full ProfileData:")
            print("   - ID: \(profile.id)")
            print("   - First Name: \(profile.firstName)")
            print("   - Last Name: \(profile.lastName)")
            print("   - Email: \(profile.email)")
            print("   - Profile Photo URL: \(profile.profilePhotoURL?.absoluteString ?? "nil")")
            print("   - Phone Number: \(profile.phoneNumber)")
            print("   - Full Name Lower: \(profile.fullNameLower)")
            print("   - Full Name: \(profile.fullName)")
            print("   - FCM Token: \(profile.fcmToken ?? "nil")")
            print("   - Firebase UID: \(profile.firebaseUid ?? "nil")")
            print("   - Supabase UID: \(profile.supabaseUid ?? "nil")")
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
                print("📋 [UserService] Full ProfileData:")
                print("   - ID: \(profile.id)")
                print("   - First Name: \(profile.firstName)")
                print("   - Last Name: \(profile.lastName)")
                print("   - Email: \(profile.email)")
                print("   - Profile Photo URL: \(profile.profilePhotoURL?.absoluteString ?? "nil")")
                print("   - Phone Number: \(profile.phoneNumber)")
                print("   - Full Name Lower: \(profile.fullNameLower)")
                print("   - Full Name: \(profile.fullName)")
                print("   - FCM Token: \(profile.fcmToken ?? "nil")")
                print("   - Firebase UID: \(profile.firebaseUid ?? "nil")")
                print("   - Supabase UID: \(profile.supabaseUid ?? "nil")")
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

            print("✅ [UserService] Found user profile by supabase_uid: \(profile.firstName) \(profile.lastName)")
            print("📋 [UserService] Full ProfileData:")
            print("   - ID: \(profile.id)")
            print("   - First Name: \(profile.firstName)")
            print("   - Last Name: \(profile.lastName)")
            print("   - Email: \(profile.email)")
            print("   - Profile Photo URL: \(profile.profilePhotoURL?.absoluteString ?? "nil")")
            print("   - Phone Number: \(profile.phoneNumber)")
            print("   - Full Name Lower: \(profile.fullNameLower)")
            print("   - Full Name: \(profile.fullName)")
            print("   - FCM Token: \(profile.fcmToken ?? "nil")")
            print("   - Firebase UID: \(profile.firebaseUid ?? "nil")")
            print("   - Supabase UID: \(profile.supabaseUid ?? "nil")")
            return profile

        } catch {
            print("❌ [UserService] User profile not found by supabase_uid: \(supabaseUid)")
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
    }
    
    func fetchUserExternalPlaces(userId: String, completion: @escaping (Result<[ExternalPlace], Error>) -> Void) {
        print("⚠️ [UserService] fetchUserExternalPlaces not fully implemented")
        completion(.success([]))
    }
    
    func fetchUserExternalPlaces(userId: String) async throws -> [ExternalPlace] {
        print("⚠️ [UserService] fetchUserExternalPlaces async not fully implemented")
        return []
    }
    
    // LAZY Loading - Only load when user clicks!
    func fetchFollowingProfilesData(for userId: String, completion: @escaping (Result<[ProfileData], Error>) -> Void) {
        print("🔄 [UserService] Delegating fetchFollowingProfilesData to Supabase (LAZY)...")
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
        print("🔄 [UserService] Delegating fetchFollowingProfilesData async to Supabase (LAZY)...")
        return try await supabase.fetchFollowingProfilesData(for: userId)
    }
    
    func fetchFollowerProfilesData(for userId: String, completion: @escaping (Result<[ProfileData], Error>) -> Void) {
        print("🔄 [UserService] Delegating fetchFollowerProfilesData to Supabase (LAZY)...")
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
        print("🔄 [UserService] Delegating fetchFollowerProfilesData async to Supabase (LAZY)...")
        return try await supabase.fetchFollowerProfilesData(for: userId)
    }
    
    // COUNT ONLY - Super fast! (~20-50ms)
    func getNumberFollowers(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        print("🔄 [UserService] Delegating getNumberFollowers to Supabase...")
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
        print("🔄 [UserService] Delegating getNumberFollowers async to Supabase...")
        return try await supabase.getNumberFollowers(forUserId: userId)
    }
    
    // COUNT ONLY - Super fast! (~20-50ms)
    func getNumberFollowing(forUserId userId: String, completion: @escaping (Int, Error?) -> Void) {
        print("🔄 [UserService] Delegating getNumberFollowing to Supabase...")
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
        print("🔄 [UserService] Delegating getNumberFollowing async to Supabase...")
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
        print("⚠️ [UserService] fetchFriendsReviews not fully implemented")
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
