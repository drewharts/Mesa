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
    
    init(userService: UserService, dataManager: DataManager) {
        self.userService = userService
        self.dataManager = dataManager
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
            
            print("✅ Signed in with Google via Supabase")
            print("👤 User ID: \(session.user.id)")
            print("👤 Email: \(session.user.email ?? "nil")")
            
            // Handle migration: find existing profile by email and migrate to new Supabase auth ID
            let googleEmail = user.profile?.email
            print("📧 Google email from profile: \(googleEmail ?? "nil")")
            print("📧 Supabase session email: \(session.user.email ?? "nil")")

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

        print("🔄 Checking for existing user profile with email: '\(email)' (length: \(email.count))")
        print("🔍 Email contains @gmail.com: \(email.contains("@gmail.com"))")
        print("🔍 Email contains @privaterelay.appleid.com: \(email.contains("@privaterelay.appleid.com"))")

        // Check if a user profile already exists with this email
        let existingUser = await findExistingUserByEmail(email: email)

        if let existingUser = existingUser {
            print("🎯 Found existing user profile! Linking to Supabase UID: \(supabaseUserId)")

            // Simply update the existing record to link it to the new Supabase auth ID
            await linkExistingUserToSupabase(
                existingUser: existingUser,
                supabaseUserId: supabaseUserId,
                userSession: userSession
            )
        } else {
            print("👤 No existing user found, creating new profile")
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
        print("🔍 Querying database for email: '\(email)'")

        do {
            let profiles: [ProfileData] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("email", value: email)
                .execute()
                .value

            print("🔍 Query returned \(profiles.count) results")

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

            if let profile = prioritizedProfiles.first {
                print("🔍 Selected profile: id=\(profile.id), firebase_uid=\(profile.firebaseUid ?? "nil"), supabase_uid=\(profile.supabaseUid ?? "nil")")
                return profile
            } else {
                print("🔍 No profile found with email '\(email)'")
                return nil
            }
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
        print("🔗 Linking existing user \(existingUser.id) to Supabase auth ID: \(supabaseUserId)")

        do {
            print("🔄 Attempting to update user record with supabase_uid...")

            // First check current state
            let beforeUpdate: [ProfileData] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("email", value: existingUser.email)
                .execute()
                .value

            if let current = beforeUpdate.first {
                print("📋 Before update: id=\(current.id), supabase_uid=\(current.supabaseUid ?? "null")")
            }

            // Simply update the existing user record to link it to the Supabase auth ID
            let updateResponse = try await SupabaseManager.shared.client
                .from("users")
                .update(["supabase_uid": supabaseUserId])
                .eq("email", value: existingUser.email)
                .execute()

            print("✅ Database update executed successfully")
            print("📊 Update response: \(updateResponse)")

            // Verify the link worked
            let verifyProfiles: [ProfileData] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("email", value: existingUser.email)
                .execute()
                .value

            if let linkedProfile = verifyProfiles.first {
                print("✅ Link verified: id=\(linkedProfile.id), supabase_uid=\(linkedProfile.supabaseUid ?? "nil")")
                if linkedProfile.supabaseUid == supabaseUserId {
                    print("✅ User successfully linked to Supabase auth!")
                } else {
                    print("❌ MISMATCH: Expected supabase_uid=\(supabaseUserId), got \(linkedProfile.supabaseUid ?? "nil")")
                }
            } else {
                print("❌ No profile found after update - this shouldn't happen!")
            }

            print("✅ User linking completed successfully")
            Task { @MainActor in
                // For existing users, keep using the original UID as the session ID
                // but they're now authenticated via Supabase
                userSession.setUserLoggedIn(uid: existingUser.id)
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
        print("👤 Creating new user profile for Supabase user: \(supabaseUserId)")

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
                    print("✅ New profile created successfully")
                    Task { @MainActor in
                        // For new users, the profile ID is the same as supabaseUserId
                        userSession.setUserLoggedIn(uid: supabaseUserId)
                        await self.dataManager.initializeProfileData(userId: supabaseUserId)
                    }
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Apple Sign-In

    func prepareAppleSignIn(request: ASAuthorizationAppleIDRequest) {
        print("🍎 Preparing Apple Sign In request...")
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        print("🍎 Apple Sign In request prepared with nonce")
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, userSession: UserSession) {
        print("🍎 Apple Sign In result received")
        
        switch result {
        case .failure(let error):
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            
        case .success(let authResults):
            print("✅ Apple Sign In successful, processing credential...")
            
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

            print("🍎 Got Apple identity token, signing in with Supabase...")
            
            Task { @MainActor in
                await authenticateWithSupabaseApple(
                    idToken: idTokenString,
                    nonce: nonce,
                    fullName: appleIDCredential.fullName,
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
            
            print("✅ Signed in with Apple via Supabase")
            print("👤 User ID: \(session.user.id)")
            print("👤 Email: \(session.user.email ?? "nil")")
            
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
                print("✅ Existing Apple user profile found")
                print("🔍 Email: \(existingUser.email)")
                
                Task { @MainActor in
                    // For existing users, use the existing profile ID, not the Supabase auth UID
                    userSession.setUserLoggedIn(uid: existingUser.id)
                    await self.dataManager.initializeProfileData(userId: existingUser.id)
                }
                
            case .failure(let error):
                if (error as NSError).code == 404 {
                    print("👤 Creating new Apple user profile...")
                    
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
                            print("✅ Apple profile created successfully")
                            Task { @MainActor in
                                userSession.setUserLoggedIn(uid: supabaseUserId)
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

