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
                userSession.isUserLoggedIn = true
                userSession.currentUserId = uid
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
                                userSession.isUserLoggedIn = true
                                userSession.currentUserId = uid
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
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, userSession: UserSession) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authResults):
            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid Apple ID credential"
                return
            }

            guard let nonce = currentNonce else {
                errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to fetch identity token"
                return
            }

            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)

            Auth.auth().signIn(with: credential) { [weak self] _, error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                self?.fetchAppleUserProfile(fullName: appleIDCredential.fullName, email: appleIDCredential.email, userSession: userSession)
            }
        }
    }

    private func fetchAppleUserProfile(fullName: PersonNameComponents?, email: String?, userSession: UserSession) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Failed to get user UID"
            return
        }

        userService.fetchUserById(userId: uid) { [weak self] result in
            switch result {
            case .success(_):
                userSession.isUserLoggedIn = true
                userSession.currentUserId = uid
                userSession.registerForFCMToken()
                Task { await self?.dataManager.initializeProfileData(userId: uid) }
            case .failure(let error):
                if (error as NSError).code == 404 {
                    Messaging.messaging().token { [weak self] token, _ in
                        let givenName = fullName?.givenName ?? ""
                        let familyName = fullName?.familyName ?? ""
                        let profileData = ProfileData(
                            id: uid,
                            firstName: givenName,
                            lastName: familyName,
                            email: email ?? "",
                            profilePhotoURL: nil,
                            phoneNumber: "",
                            fullNameLower: "\(givenName) \(familyName)".lowercased(),
                            fullName: "\(givenName) \(familyName)",
                            fcmToken: token
                        )
                        self?.userService.saveUserProfile(uid: uid, profileData: profileData) { [weak self] error in
                            if let error = error {
                                self?.errorMessage = "Error saving profile: \(error.localizedDescription)"
                            } else {
                                userSession.isUserLoggedIn = true
                                userSession.currentUserId = uid
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
