//
//  UserSession.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//


import FirebaseAuth
import GoogleSignIn

class UserSession: ObservableObject {
    @Published var isUserLoggedIn: Bool = false

    func logout() {
        do {
            // Sign out from Firebase
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            // Update login state
            isUserLoggedIn = false
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
}

