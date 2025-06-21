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

class LoginViewModel: ObservableObject {
    @Published var errorMessage: String?
    private let userService: UserService
    private let dataManager: DataManager
    
    
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

}
