//
//  LoginViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//


import SwiftUI
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import AuthenticationServices
import CryptoKit

@MainActor
class LoginViewModel: ObservableObject {
    @Published var errorMessage: String?
    private let userService: UserService
    private let dataManager: DataManager
    private var currentNonce: String?
    
    
    init(userService: UserService, dataManager: DataManager) {
        self.userService = userService
        self.dataManager = dataManager
    }

    func signInWithGoogle(userSession: UserSession) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Missing client ID"
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
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self?.errorMessage = "Failed to retrieve user credentials"
                return
            }

            let accessToken = user.accessToken.tokenString
            self?.authenticateWithFirebase(idToken: idToken, accessToken: accessToken, user: user, userSession: userSession)
        }
    }

    private func authenticateWithFirebase(idToken: String, accessToken: String, user: GIDGoogleUser, userSession: UserSession) {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                if let firebaseUser = authResult?.user {
                    print("👤 Google Sign In - Firebase user UID: \(firebaseUser.uid)")
                    print("👤 Google Sign In - Firebase user email: \(firebaseUser.email ?? "nil")")
                    print("👤 Google Sign In - Firebase user provider data:")
                    for profile in firebaseUser.providerData {
                        print("   - Provider: \(profile.providerID), UID: \(profile.uid), Email: \(profile.email ?? "nil")")
                    }
                    
                    // SECURITY CHECK: Ensure user is actually signed in with Google, not linked to Apple
                    let hasGoogleProvider = firebaseUser.providerData.contains { $0.providerID == "google.com" }
                    let hasAppleProvider = firebaseUser.providerData.contains { $0.providerID == "apple.com" }
                    
                    if hasAppleProvider && !hasGoogleProvider {
                        print("🚨 SECURITY ISSUE: User signed in with Google but got linked to Apple account!")
                        print("🚨 Signing out for security...")
                        
                        // Sign out immediately for security
                        do {
                            try Auth.auth().signOut()
                            self?.errorMessage = "Security issue: Account linking detected. Please use a different email or contact support."
                        } catch {
                            print("❌ Error signing out: \(error)")
                            self?.errorMessage = "Security error occurred. Please try again."
                        }
                        return
                    }
                    
                    if hasGoogleProvider {
                        print("✅ User properly signed in with Google")
                    }
                }
                
                self?.fetchGoogleUserProfile(user: user, userSession: userSession)
            }
        }
    }

    private func fetchGoogleUserProfile(user: GIDGoogleUser, userSession: UserSession) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Failed to get user UID"
            return
        }

        // Check if profile exists first
        userService.fetchUserById(userId: uid) { [weak self] result in
            switch result {
            case .success(_):
                // Profile exists, update FCM token and proceed
                userSession.setUserLoggedIn(uid: uid)
                userSession.registerForFCMToken()
                Task {
                    await self?.dataManager.initializeProfileData(userId: uid)
                }
            case .failure(let error):
                // Only create if not found (404)
                if (error as NSError).code == 404 {
                    // Get FCM token for new user
                    Messaging.messaging().token { [weak self] token, error in
                        let profileData = ProfileData(
                            id: uid,
                            firstName: user.profile?.givenName ?? "",
                            lastName: user.profile?.familyName ?? "",
                            email: user.profile?.email ?? "",
                            profilePhotoURL: user.profile?.imageURL(withDimension: 200),
                            phoneNumber: "",
                            fullNameLower: "\(user.profile?.givenName ?? "") \(user.profile?.familyName ?? "")".lowercased(),
                            fullName: "\(user.profile?.givenName ?? "") \(user.profile?.familyName ?? "")",
                            fcmToken: token
                        )
                        self?.userService.saveUserProfile(uid: uid, profileData: profileData) { [weak self] error in
                            if let error = error {
                                self?.errorMessage = "Error saving profile: \(error.localizedDescription)"
                            } else {
                                userSession.setUserLoggedIn(uid: uid)
                                userSession.registerForFCMToken()
                            }
                        }
                    }
                } else {
                    self?.errorMessage = "Error fetching profile: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Sign in with Apple

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

            print("🍎 Got Apple ID token, creating Firebase credential...")
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)

            print("🔥 Signing in with Firebase...")
            print("🍎 Apple email: \(appleIDCredential.email ?? "nil")")
            print("🍎 Apple user ID: \(appleIDCredential.user)")
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    print("❌ Firebase sign in failed: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    return
                }

                print("✅ Firebase sign in successful!")
                if let user = authResult?.user {
                    print("👤 Firebase user UID: \(user.uid)")
                    print("👤 Firebase user email: \(user.email ?? "nil")")
                    print("👤 Firebase user provider data:")
                    for profile in user.providerData {
                        print("   - Provider: \(profile.providerID), UID: \(profile.uid), Email: \(profile.email ?? "nil")")
                    }
                    
                    // SECURITY CHECK: Ensure user is actually signed in with Apple, not linked to Google
                    let hasAppleProvider = user.providerData.contains { $0.providerID == "apple.com" }
                    let hasGoogleProvider = user.providerData.contains { $0.providerID == "google.com" }
                    
                    print("🔍 Security check - Apple provider: \(hasAppleProvider), Google provider: \(hasGoogleProvider)")
                    print("🔍 Provider count: \(user.providerData.count)")
                    
                    // STRICT SECURITY: Only allow pure Apple authentication
                    if !hasAppleProvider {
                        print("🚨 SECURITY ISSUE: User signed in with Apple but no Apple provider found!")
                        print("🚨 Signing out for security...")
                        
                        // Sign out immediately for security
                        do {
                            try Auth.auth().signOut()
                            self?.errorMessage = "Security issue: Invalid authentication method. Please try again."
                        } catch {
                            print("❌ Error signing out: \(error)")
                            self?.errorMessage = "Security error occurred. Please try again."
                        }
                        return
                    }
                    
                    // Check for any other providers (Google, etc.)
                    let otherProviders = user.providerData.filter { $0.providerID != "apple.com" }
                    if !otherProviders.isEmpty {
                        print("🚨 SECURITY ISSUE: User signed in with Apple but has other providers: \(otherProviders.map { $0.providerID })")
                        print("🚨 Signing out for security...")
                        
                        // Sign out immediately for security
                        do {
                            try Auth.auth().signOut()
                            self?.errorMessage = "Security issue: Account linking detected. Please use a different email or contact support."
                        } catch {
                            print("❌ Error signing out: \(error)")
                            self?.errorMessage = "Security error occurred. Please try again."
                        }
                        return
                    }
                    
                    if hasAppleProvider && otherProviders.isEmpty {
                        print("✅ User properly signed in with Apple (no other providers)")
                    }
                }
                
                self?.fetchAppleUserProfile(fullName: appleIDCredential.fullName, email: appleIDCredential.email, userSession: userSession)
            }
        }
    }

    private func fetchAppleUserProfile(fullName: PersonNameComponents?, email: String?, userSession: UserSession) {
        print("👤 Fetching Apple user profile...")
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ Failed to get user UID from Firebase")
            errorMessage = "Failed to get user UID"
            return
        }
        
        print("👤 User UID: \(uid)")

        userService.fetchUserById(userId: uid) { [weak self] result in
            switch result {
            case .success(let existingUser):
                print("✅ User already exists in database")
                print("🔍 Existing user email: \(existingUser.email)")
                print("🔍 Existing user name: \(existingUser.fullName)")
                
                // SECURITY CHECK: Ensure this is actually an Apple user
                if !existingUser.email.contains("privaterelay.appleid.com") && !existingUser.email.isEmpty {
                    print("🚨 SECURITY ISSUE: Existing user found but not an Apple private relay email!")
                    print("🚨 This suggests account linking. Signing out for security...")
                    
                    // Sign out immediately for security
                    do {
                        try Auth.auth().signOut()
                        self?.errorMessage = "Security issue: Account linking detected. Please use a different email or contact support."
                    } catch {
                        print("❌ Error signing out: \(error)")
                        self?.errorMessage = "Security error occurred. Please try again."
                    }
                    return
                }
                
                userSession.setUserLoggedIn(uid: uid)
                userSession.registerForFCMToken()
                Task { await self?.dataManager.initializeProfileData(userId: uid) }
                print("🎉 User successfully logged in!")
            case .failure(let error):
                print("❌ Error fetching user: \(error.localizedDescription)")
                if (error as NSError).code == 404 {
                    print("👤 User not found, creating new profile...")
                    Messaging.messaging().token { [weak self] token, _ in
                        let givenName = fullName?.givenName ?? ""
                        let familyName = fullName?.familyName ?? ""
                        // SECURITY: Ensure no profile photo URL for Apple users (they don't get one from Apple)
                        let profileData = ProfileData(
                            id: uid,
                            firstName: givenName,
                            lastName: familyName,
                            email: email ?? "",
                            profilePhotoURL: nil, // Apple doesn't provide profile photos
                            phoneNumber: "",
                            fullNameLower: "\(givenName) \(familyName)".lowercased(),
                            fullName: "\(givenName) \(familyName)",
                            fcmToken: token
                        )
                        print("💾 Saving new user profile...")
                        self?.userService.saveUserProfile(uid: uid, profileData: profileData) { [weak self] error in
                            if let error = error {
                                print("❌ Error saving profile: \(error.localizedDescription)")
                                self?.errorMessage = "Error saving profile: \(error.localizedDescription)"
                            } else {
                                print("✅ Profile saved successfully!")
                                userSession.setUserLoggedIn(uid: uid)
                                userSession.registerForFCMToken()
                                print("🎉 New user successfully logged in!")
                            }
                        }
                    }
                } else {
                    print("❌ Unexpected error: \(error.localizedDescription)")
                    self?.errorMessage = "Error fetching profile: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Nonce helpers

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
