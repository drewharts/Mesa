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
    @StateObject private var selectedPlaceVM = SelectedPlaceViewModel(locationManager:  LocationManager(), firestoreService: FirestoreService())

    var body: some View {
        if userSession.isUserLoggedIn {
            if let profileViewModel = userSession.profileViewModel {
                // Once profileViewModel is available, inject it into the environment
                MainView()
                    .environmentObject(profileViewModel)
                    .environmentObject(locationManager)
                    .environmentObject(selectedPlaceVM)
            } else {
                ProgressView("Loading profile...")
            }
        } else {
            LoginView(viewModel: LoginViewModel(firestoreService: FirestoreService()))
        }
    }
}

