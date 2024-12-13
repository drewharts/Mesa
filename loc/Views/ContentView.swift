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
    @ObservedObject var locationManager = LocationManager()

    var body: some View {
        Group {
            if userSession.isUserLoggedIn {
                if let profileViewModel = userSession.profileViewModel {
                    // Once profileViewModel is available, inject it into the environment
                    MainView(locationManager: locationManager)
                        .environmentObject(profileViewModel)
                } else {
                    // If profileViewModel isn't loaded yet, show a loading state or nothing
                    ProgressView("Loading profile...")
                }
            } else {
                LoginView()
            }
        }
    }
}
