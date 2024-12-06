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

class LoginViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var isUserLoggedIn = false
    @Published var profile: Profile?

    func signInWithGoogle() {
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
            self?.authenticateWithFirebase(idToken: idToken, accessToken: accessToken, user: user)
        }
    }

    private func authenticateWithFirebase(idToken: String, accessToken: String, user: GIDGoogleUser) {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.fetchGoogleUserProfile(user: user)
            }
        }
    }

    private func fetchGoogleUserProfile(user: GIDGoogleUser) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Failed to get user UID"
            return
        }

        let db = Firestore.firestore()

        let userModel = User(
            firstName: user.profile?.givenName ?? "",
            lastName: user.profile?.familyName ?? "",
            email: user.profile?.email ?? "",
            profilePhotoURL: user.profile?.imageURL(withDimension: 200)
        )

        let profile = Profile(user: userModel, phoneNumber: "")

        let profileData: [String: Any] = [
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "email": profile.email,
            "profilePhotoURL": profile.profilePhoto ?? "",
            "phoneNumber": profile.phoneNumber,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection("profiles").document(uid).setData(profileData) { [weak self] error in
            if let error = error {
                self?.errorMessage = "Error saving profile: \(error.localizedDescription)"
            } else {
                self?.profile = profile
                self?.isUserLoggedIn = true
            }
        }
    }
}
