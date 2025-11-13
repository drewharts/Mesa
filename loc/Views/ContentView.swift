//
//  ContentView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//  Refactored to enterprise architecture on 11/13/25
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    // ViewModels passed as props, not environment objects
    let selectedPlaceViewModel: SelectedPlaceViewModel
    let profileViewModel: ProfileViewModel
    let userProfileViewModel: UserProfileViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let deepLinkViewModel: DeepLinkViewModel
    let deepLinkManager: DeepLinkManager
    let notificationManager: NotificationManager
    let dataManager: DataManager
    let serviceContainer: ServiceContainer
    
    @State private var showNavigationError = false
    @State private var navigationErrorMessage = ""

    var body: some View {
        if userSession.isUserLoggedIn {
            MainView(
                selectedPlaceVM: selectedPlaceViewModel,
                profileViewModel: profileViewModel,
                userProfileViewModel: userProfileViewModel,
                detailPlaceViewModel: detailPlaceViewModel,
                deepLinkViewModel: deepLinkViewModel,
                notificationManager: notificationManager,
                deepLinkManager: deepLinkManager,
                dataManager: dataManager,
                serviceContainer: serviceContainer
            )
            .onReceive(notificationManager.$pendingNavigation) { pendingNavigation in
                handleNotificationNavigation(pendingNavigation)
            }
            .alert("Navigation Error", isPresented: $showNavigationError) {
                Button("OK") { }
            } message: {
                Text(navigationErrorMessage)
            }
        } else {
            LoginView(viewModel: LoginViewModel(userService: serviceContainer.userService, dataManager: dataManager))
        }
    }
    
    private func handleNotificationNavigation(_ pendingNavigation: PendingNavigation?) {
        guard let navigation = pendingNavigation else { return }
        
        // Ensure user is properly logged in before processing notification
        guard userSession.isUserLoggedIn, userSession.currentUserId != nil else {
            print("⚠️ Cannot process notification - user not logged in")
            notificationManager.clearPendingNavigation()
            notificationManager.clearHighlightedReview()
            return
        }
        
        print("🚀 Processing notification navigation to place: \(navigation.placeId), review: \(navigation.reviewId)")
        
        // Fetch the place details first
        serviceContainer.placeService.getDetailPlace(mapboxId: navigation.placeId) { place in
            if let place = place {
                print("✅ Found place: \(place.name)")
                
                // Animate map to place location when navigating from notification
                selectedPlaceViewModel.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
                selectedPlaceViewModel.isDetailSheetPresented = true
                
                // Clear the pending navigation but keep the highlighted review ID
                notificationManager.clearPendingNavigation()
                
                print("📍 Navigated to place detail view, highlighting review: \(navigation.reviewId)")
            } else {
                print("❌ Failed to fetch place details")
                
                // Show user-friendly error
                navigationErrorMessage = "Sorry, we couldn't find that place. It may have been removed."
                showNavigationError = true
                
                notificationManager.clearPendingNavigation()
                notificationManager.clearHighlightedReview()
            }
        }
    }
}

