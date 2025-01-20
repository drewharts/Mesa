//
//  UserSession.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//

import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore
import GooglePlaces
import SwiftUI

class UserSession: ObservableObject {
    @Published var isUserLoggedIn: Bool = false
    @Published var profileViewModel: ProfileViewModel?
    @Published var locationManager: LocationManager
    private let firestoreService: FirestoreService
    let googlePlacesService: GooglePlacesService
    
    init(firestoreService: FirestoreService) {
        self.locationManager = LocationManager()
        self.firestoreService = firestoreService
        let placesClient = GMSPlacesClient.shared()
        self.googlePlacesService = GooglePlacesService(placesClient: placesClient)
        // Check if a user is already signed in
        if let currentUser = Auth.auth().currentUser {
            self.isUserLoggedIn = true
            fetchProfile(for: currentUser.uid)
        } else {
            self.isUserLoggedIn = false
            self.profileViewModel = nil
        }
    }

    func logout() {
        do {
            // Sign out from Firebase
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            
            // Update login state
            isUserLoggedIn = false
            profileViewModel = nil
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
    
    func fetchProfile(for uid: String) {
        let docRef = Firestore.firestore().collection("users").document(uid)
        docRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching profile: \(error.localizedDescription)")
                return
            }

            guard let document = document, document.exists else {
                print("No profile found for user \(uid)")
                return
            }

            do {
                // Decode the firestore data into ProfileData
                let profileData = try document.data(as: ProfileData.self)
                
                // Create a ProfileViewModel from ProfileData
                let profileViewModel = ProfileViewModel(data: profileData, firestoreService: self.firestoreService, googlePlacesService: self.googlePlacesService, userId: uid)

                // Assign it to our session
                self.profileViewModel = profileViewModel
            } catch {
                print("Error decoding profile data: \(error)")
            }
        }
    }
    
    func signInWithGoogle(user: GIDGoogleUser) {
        guard let idToken = user.idToken?.tokenString else { return }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                print("Firebase sign-in error: \(error.localizedDescription)")
                return
            }
            
            // Sign-in successful
            self.isUserLoggedIn = true
            if let currentUser = Auth.auth().currentUser {
                self.fetchProfile(for: currentUser.uid)
            }
        }
    }
}
