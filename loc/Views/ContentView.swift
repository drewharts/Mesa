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
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel

    var body: some View {
        if userSession.isUserLoggedIn {
            MainView()
                .environmentObject(profileViewModel)
                .environmentObject(locationManager)
                .environmentObject(selectedPlaceVM)
                .environmentObject(detailPlaceVM)
                .environmentObject(userProfileViewModel)
                .environmentObject(firestoreService)
        } else {
            LoginView(viewModel: LoginViewModel(firestoreService: firestoreService, dataManager: dataManager))
        }
    }
}

