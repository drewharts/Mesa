//
//  ContentView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//
//  Updated to align with Profile and UserSession changes

import SwiftUI
import FirebaseAuth
import FirebaseMessaging

struct ContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    // TODO: not sure if this is how we want to do it with env vars for specific services?
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var placeService: PlaceService
    
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showNavigationError = false
    @State private var navigationErrorMessage = ""

    var body: some View {
        if userSession.isUserLoggedIn {
            MainView()
                .environmentObject(profileViewModel)
                .environmentObject(locationManager)
                .environmentObject(selectedPlaceVM)
                .environmentObject(detailPlaceVM)
                .environmentObject(userProfileViewModel)
                .onReceive(notificationManager.$pendingNavigation) { pendingNavigation in
                    handleNotificationNavigation(pendingNavigation)
                }
                .alert("Navigation Error", isPresented: $showNavigationError) {
                    Button("OK") { }
                } message: {
                    Text(navigationErrorMessage)
                }
        } else {
            LoginView(viewModel: LoginViewModel(userService: userService, dataManager: dataManager))
        }
    }
    
    private func handleNotificationNavigation(_ pendingNavigation: PendingNavigation?) {
        guard let navigation = pendingNavigation else { return }
        
        print("🚀 Processing notification navigation to place: \(navigation.placeId), review: \(navigation.reviewId)")
        
        // Fetch the place details first
        placeService.getDetailPlace(placeId: navigation.placeId) { place, error in
            DispatchQueue.main.async {
                if let place = place {
                    print("✅ Found place: \(place.name ?? "Unknown")")
                    
                    // Set the selected place and show the detail sheet
                    selectedPlaceVM.selectedPlace = place
                    selectedPlaceVM.isDetailSheetPresented = true
                    
                    // Clear the pending navigation but keep the highlighted review ID
                    notificationManager.clearPendingNavigation()
                    
                    print("📍 Navigated to place detail view, highlighting review: \(navigation.reviewId)")
                } else {
                    let errorMsg = error?.localizedDescription ?? "Place not found"
                    print("❌ Failed to fetch place details: \(errorMsg)")
                    
                    // Show user-friendly error
                    navigationErrorMessage = "Sorry, we couldn't find that place. It may have been removed."
                    showNavigationError = true
                    
                    notificationManager.clearPendingNavigation()
                    notificationManager.clearHighlightedReview()
                }
            }
        }
    }
}

