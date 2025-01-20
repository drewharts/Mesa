//
//  ContentView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//
//  Updated to align with Profile and UserSession changes

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var userSession: UserSession
    // No need to observe LocationManager here anymore

    var body: some View {
        if userSession.isUserLoggedIn {
            // Check if the profile data is loaded
            if userSession.profileViewModel != nil {
                // Pass userSession to MainView
                MainView(userSession: userSession)
                    .environmentObject(userSession)
            } else {
                ProgressView("Loading profile...")
            }
        } else {
            LoginView(viewModel: LoginViewModel(firestoreService: FirestoreService(), googleplacesService: userSession.googlePlacesService))
                .environmentObject(userSession)
        }
    }
}
