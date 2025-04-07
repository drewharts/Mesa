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
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var userProfileViewModel = UserProfileViewModel()

    var body: some View {
        if userSession.isUserLoggedIn {
            if let profileViewModel = userSession.profileViewModel {
                MainView()
                    .environmentObject(profileViewModel)
                    .environmentObject(locationManager)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceVM)
                    .environmentObject(userProfileViewModel)
            } else {
                ProgressView("Loading profile...")
            }
        } else {
            LoginView(viewModel: LoginViewModel(firestoreService: firestoreService))
        }
    }
}

