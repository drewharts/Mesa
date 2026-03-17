//
//  LoginViewModel.swift
//  loc
//
//  Updated to use Supabase Authentication
//

import SwiftUI
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import Supabase

@MainActor
class LoginViewModel: ObservableObject {
    @Published var errorMessage: String?
    private let userService: UserService
    private let dataManager: DataManager
    private let authService = SupabaseAuthService.shared
    private var currentNonce: String?
    
    // MARK: - Apple Name Caching
    // Apple only provides the user's name on the FIRST authorization ever.
    // We must cache it immediately to handle network failures or retries.
    private let appleNameCacheKey = "cachedAppleFullName"
    
    init(userService: UserService, dataManager: DataManager) {
        self.userService = userService
        self.dataManager = dataManager
    }
    
    private func cacheAppleName(_ fullName: PersonNameComponents?) {
        guard let fullName = fullName,
              let givenName = fullName.givenName, !givenName.isEmpty else {
            return // Don't cache empty names
        }
        
        let nameDict: [String: String] = [
            "givenName": givenName,
            "familyName": fullName.familyName ?? ""
        ]
        UserDefaults.standard.set(nameDict, forKey: appleNameCacheKey)
    }
    
    private func getCachedAppleName() -> PersonNameComponents? {
        guard let nameDict = UserDefaults.standard.dictionary(forKey: appleNameCacheKey) as? [String: String],
              let givenName = nameDict["givenName"], !givenName.isEmpty else {
            return nil
        }
        
        var components = PersonNameComponents()
        components.givenName = givenName
        components.familyName = nameDict["familyName"]
        return components
    }
    
    private func clearCachedAppleName() {
        UserDefaults.standard.removeObject(forKey: appleNameCacheKey)
    }

    // MARK: - Google Sign-In
    
    func signInWithGoogle(userSession: UserSession) {
        // Get Google Client ID from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistConfig = NSDictionary(contentsOfFile: path),
              let clientID = plistConfig["CLIENT_ID"] as? String else {
            errorMessage = "Missing Google client ID in GoogleService-Info.plist"
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
                errorMessage = "Unable to access root view controller"
                return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                Task { @MainActor in
                    self.errorMessage = "Failed to retrieve user credentials"
                }
                return
            }

            Task { @MainActor in
                await self.authenticateWithSupabase(idToken: idToken, user: user, userSession: userSession)
            }
        }
    }

    private func authenticateWithSupabase(idToken: String, user: GIDGoogleUser, userSession: UserSession) async {
        do {
            // Sign in with Supabase using Google OAuth token
            let session = try await authService.signInWithIdToken(provider: .google, idToken: idToken)
            
            // Handle migration: find existing profile by email and migrate to new Supabase auth ID
            let googleEmail = user.profile?.email

            await handleUserMigration(
                email: googleEmail ?? session.user.email,
                supabaseUserId: session.user.id.uuidString,
                userProfile: user.profile,
                userSession: userSession
            )
            
        } catch {
            print("❌ Supabase Google sign-in error: \(error.localizedDescription)")
            errorMessage = "Failed to sign in with Google: \(error.localizedDescription)"
        }
    }

    private func handleUserMigration(
        email: String?,
        supabaseUserId: String,
        userProfile: GIDProfileData? = nil,
        appleFullName: PersonNameComponents? = nil,
        appleEmail: String? = nil,
        userSession: UserSession
    ) async {
        guard let email = email else {
            print("❌ No email provided for migration")
            await createNewUserProfile(
                supabaseUserId: supabaseUserId,
                email: "",
                userProfile: userProfile,
                appleFullName: appleFullName,
                appleEmail: appleEmail,
                userSession: userSession
            )
            return
        }

        // Check if a user profile already exists with this email
        let existingUser = await findExistingUserByEmail(email: email)

        if let existingUser = existingUser {
            // Simply update the existing record to link it to the new Supabase auth ID
            await linkExistingUserToSupabase(
                existingUser: existingUser,
                supabaseUserId: supabaseUserId,
                userSession: userSession
            )
        } else {
            // No existing user, create new profile with Supabase auth ID
            await createNewUserProfile(
                supabaseUserId: supabaseUserId,
                email: email,
                userProfile: userProfile,
                appleFullName: appleFullName,
                appleEmail: appleEmail,
                userSession: userSession
            )
        }
    }

    private func findExistingUserByEmail(email: String) async -> ProfileData? {
        do {
            let profiles: [ProfileData] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("email", value: email)
                .execute()
                .value

            // If multiple profiles with same email, prioritize:
            // 1. Original users (have firebase_uid set)
            // 2. Users without supabase_uid set (not fully migrated)
            // 3. Any remaining user
            let prioritizedProfiles = profiles.sorted { (a, b) -> Bool in
                // Prefer users with firebase_uid (original users)
                if a.firebaseUid != nil && b.firebaseUid == nil {
                    return true
                }
                if b.firebaseUid != nil && a.firebaseUid == nil {
                    return false
                }

                // Then prefer users without supabase_uid (not migrated yet)
                if a.supabaseUid == nil && b.supabaseUid != nil {
                    return true
                }
                if b.supabaseUid == nil && a.supabaseUid != nil {
                    return false
                }

                // Finally, prefer older records (by ID if they're UUIDs)
                return a.id < b.id
            }

            return prioritizedProfiles.first
        } catch {
            print("❌ Error searching for existing user: \(error.localizedDescription)")
            print("❌ Query failed for email: '\(email)'")
            return nil
        }
    }

    private func linkExistingUserToSupabase(
        existingUser: ProfileData,
        supabaseUserId: String,
        userSession: UserSession
    ) async {
        do {
            // Simply update the existing user record to link it to the Supabase auth ID
            let updateResponse = try await SupabaseManager.shared.client
                .from("users")
                .update(["supabase_uid": supabaseUserId])
                .eq("email", value: existingUser.email)
                .execute()

            // Suppress unused variable warning
            _ = updateResponse

            // Clear any cached Apple name since existing user already has profile data
            clearCachedAppleName()
            Task { @MainActor in
                // For existing users, keep using the original UID as the session ID
                // but they're now authenticated via Supabase
                userSession.setUserLoggedIn(uid: existingUser.id)
                userSession.needsPhoneOnboarding = !UserSession.hasCompletedPhoneOnboarding
                userSession.needsProfilePhoto = !UserSession.hasCompletedPhotoOnboarding
                userSession.needsListOnboarding = !UserSession.hasCompletedListOnboarding
                await self.dataManager.initializeProfileData(userId: existingUser.id)
            }

        } catch {
            print("❌ Error linking user to Supabase: \(error.localizedDescription)")
            Task { @MainActor in
                self.errorMessage = "Error linking user account: \(error.localizedDescription)"
            }
        }
    }

    private func updateRelatedTables(oldUserId: String, newUserId: String) async {
        do {
            // Update favorites
            try await SupabaseManager.shared.client
                .from("favorites")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update following (both follower and following)
            try await SupabaseManager.shared.client
                .from("following")
                .update(["follower_id": newUserId])
                .eq("follower_id", value: oldUserId)
                .execute()

            try await SupabaseManager.shared.client
                .from("following")
                .update(["following_id": newUserId])
                .eq("following_id", value: oldUserId)
                .execute()

            // Update place lists
            try await SupabaseManager.shared.client
                .from("place_lists")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update reviews
            try await SupabaseManager.shared.client
                .from("reviews")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update comments
            try await SupabaseManager.shared.client
                .from("comments")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update my_places
            try await SupabaseManager.shared.client
                .from("my_places")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update external_places
            try await SupabaseManager.shared.client
                .from("external_places")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update place_notes
            try await SupabaseManager.shared.client
                .from("place_notes")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update tik_tok_place_flags
            try await SupabaseManager.shared.client
                .from("tik_tok_place_flags")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update user_notifications
            try await SupabaseManager.shared.client
                .from("user_notifications")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

            // Update review_likes
            try await SupabaseManager.shared.client
                .from("review_likes")
                .update(["user_id": newUserId])
                .eq("user_id", value: oldUserId)
                .execute()

        } catch {
            print("❌ Error updating related tables: \(error.localizedDescription)")
        }
    }

    private func createNewUserProfile(
        supabaseUserId: String,
        email: String,
        userProfile: GIDProfileData? = nil,
        appleFullName: PersonNameComponents? = nil,
        appleEmail: String? = nil,
        userSession: UserSession
    ) async {
        // Determine profile data from either Google or Apple
        let firstName: String
        let lastName: String
        let profilePhotoURL: URL?

        if let googleProfile = userProfile {
            // Google profile data
            firstName = googleProfile.givenName ?? ""
            lastName = googleProfile.familyName ?? ""
            profilePhotoURL = googleProfile.imageURL(withDimension: 200)
        } else if let appleName = appleFullName {
            // Apple profile data
            firstName = appleName.givenName ?? ""
            lastName = appleName.familyName ?? ""
            profilePhotoURL = nil  // Apple doesn't provide profile photos
        } else {
            // Fallback
            firstName = ""
            lastName = ""
            profilePhotoURL = nil
        }

                    let profileData = ProfileData(
                        id: supabaseUserId,
              firstName: firstName,
              lastName: lastName,
              email: email,
              profilePhotoURL: profilePhotoURL,
                        phoneNumber: "",
              fullNameLower: "\(firstName) \(lastName)".lowercased(),
              fullName: "\(firstName) \(lastName)",
              fcmToken: nil,  // TODO: Implement push notifications with Supabase
              firebaseUid: nil,
              supabaseUid: supabaseUserId  // New users have supabase_uid = id
          )

        await withCheckedContinuation { continuation in
            userService.saveUserProfile(uid: supabaseUserId, profileData: profileData) { [weak self] error in
                guard let self = self else { return }

                        if let error = error {
                    print("❌ Error creating new profile: \(error.localizedDescription)")
                            Task { @MainActor in
                        self.errorMessage = "Error creating profile: \(error.localizedDescription)"
                    }
                } else {
                    // Clear cached Apple name after successful profile creation
                    self.clearCachedAppleName()
                    Task { @MainActor in
                        // For new users, the profile ID is the same as supabaseUserId
                        userSession.setUserLoggedIn(uid: supabaseUserId)
                        userSession.needsPhoneOnboarding = !UserSession.hasCompletedPhoneOnboarding
                        userSession.needsProfilePhoto = !UserSession.hasCompletedPhotoOnboarding
                        userSession.needsListOnboarding = !UserSession.hasCompletedListOnboarding
                        await self.dataManager.initializeProfileData(userId: supabaseUserId)
                    }
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Apple Sign-In

    func prepareAppleSignIn(request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, userSession: UserSession) {
        switch result {
        case .failure(let error):
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            
        case .success(let authResults):
            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ Invalid Apple ID credential type")
                errorMessage = "Invalid Apple ID credential"
                return
            }

            guard let nonce = currentNonce else {
                print("❌ No nonce found - invalid state")
                errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("❌ Unable to get identity token from Apple")
                errorMessage = "Unable to fetch identity token"
                return
            }

            // 🍎 CRITICAL: Cache the name IMMEDIATELY before any network calls
            // Apple only provides the name on the very first authorization
            if let fullName = appleIDCredential.fullName, fullName.givenName != nil {
                cacheAppleName(fullName)
            }
            
            // Use cached name if credential doesn't have one (subsequent sign-ins)
            let effectiveFullName: PersonNameComponents?
            if appleIDCredential.fullName?.givenName != nil {
                effectiveFullName = appleIDCredential.fullName
            } else {
                effectiveFullName = getCachedAppleName()
            }
            
            Task { @MainActor in
                await authenticateWithSupabaseApple(
                    idToken: idTokenString,
                    nonce: nonce,
                    fullName: effectiveFullName,
                    email: appleIDCredential.email,
                    userSession: userSession
                )
            }
        }
    }

    private func authenticateWithSupabaseApple(
        idToken: String,
        nonce: String,
        fullName: PersonNameComponents?,
        email: String?,
        userSession: UserSession
    ) async {
        do {
            // Sign in with Supabase using Apple identity token
            let session = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            
            // Handle migration: find existing profile by email and migrate to new Supabase auth ID
            await handleUserMigration(
                email: email ?? session.user.email,
                supabaseUserId: session.user.id.uuidString,
                appleFullName: fullName,
                appleEmail: email,
                userSession: userSession
            )
            
        } catch {
            print("❌ Supabase Apple sign-in error: \(error.localizedDescription)")
            errorMessage = "Failed to sign in with Apple: \(error.localizedDescription)"
        }
    }

    private func fetchOrCreateAppleProfile(
        supabaseUserId: String,
        fullName: PersonNameComponents?,
        email: String?,
        userSession: UserSession
    ) async {
        userService.fetchUserById(userId: supabaseUserId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let existingUser):
                Task { @MainActor in
                    // For existing users, use the existing profile ID, not the Supabase auth UID
                    userSession.setUserLoggedIn(uid: existingUser.id)
                    userSession.needsPhoneOnboarding = !UserSession.hasCompletedPhoneOnboarding
                    userSession.needsProfilePhoto = !UserSession.hasCompletedPhotoOnboarding
                    userSession.needsListOnboarding = !UserSession.hasCompletedListOnboarding
                    await self.dataManager.initializeProfileData(userId: existingUser.id)
                }

            case .failure(let error):
                if (error as NSError).code == 404 {
                    let givenName = fullName?.givenName ?? ""
                    let familyName = fullName?.familyName ?? ""

                    let profileData = ProfileData(
                        id: supabaseUserId,
                        firstName: givenName,
                        lastName: familyName,
                        email: email ?? "",
                        profilePhotoURL: nil,  // Apple doesn't provide profile photos
                        phoneNumber: "",
                        fullNameLower: "\(givenName) \(familyName)".lowercased(),
                        fullName: "\(givenName) \(familyName)",
                        fcmToken: nil  // TODO: Implement push notifications with Supabase
                    )

                    self.userService.saveUserProfile(uid: supabaseUserId, profileData: profileData) { [weak self] error in
                        if let error = error {
                            Task { @MainActor in
                                self?.errorMessage = "Error saving profile: \(error.localizedDescription)"
                            }
                        } else {
                            Task { @MainActor in
                                userSession.setUserLoggedIn(uid: supabaseUserId)
                                userSession.needsPhoneOnboarding = !UserSession.hasCompletedPhoneOnboarding
                                userSession.needsProfilePhoto = !UserSession.hasCompletedPhotoOnboarding
                                userSession.needsListOnboarding = !UserSession.hasCompletedListOnboarding
                            }
                        }
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Error fetching profile: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

