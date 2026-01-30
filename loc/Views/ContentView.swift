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
    let userProfileNavigationViewModel: UserProfileNavigationViewModel
    let mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let deepLinkViewModel: DeepLinkViewModel
    let deepLinkManager: DeepLinkManager
    let notificationManager: NotificationManager
    let dataManager: DataManager
    let serviceContainer: ServiceContainer
    let searchViewModel: SearchViewModel  // ✅ Accept from parent
    let searchCoordinator: SearchCoordinatorViewModel  // ✅ Search coordinator
    
    @State private var showNavigationError = false
    @State private var navigationErrorMessage = ""

    var body: some View {
        // ✅ Staff Engineer: Use visibility, not conditional rendering (prevents destruction)
        ZStack {
            // MainView always exists (never destroyed/recreated)
            MainView(
                selectedPlaceVM: selectedPlaceViewModel,
                profileViewModel: profileViewModel,
                userProfileNavigationViewModel: userProfileNavigationViewModel,
                mapDisplayCoordinatorViewModel: mapDisplayCoordinatorViewModel,
                detailPlaceViewModel: detailPlaceViewModel,
                deepLinkViewModel: deepLinkViewModel,
                notificationManager: notificationManager,
                searchViewModel: searchViewModel,
                searchCoordinator: searchCoordinator,
                deepLinkManager: deepLinkManager,
                dataManager: dataManager,
                serviceContainer: serviceContainer
            )
            .opacity(userSession.isUserLoggedIn ? 1 : 0)
            .allowsHitTesting(userSession.isUserLoggedIn)
            .onReceive(notificationManager.$pendingNavigation) { pendingNavigation in
                handleNotificationNavigation(pendingNavigation)
            }
            
            // LoginView overlays when not logged in
            if !userSession.isUserLoggedIn {
                LoginView(
                    viewModel: LoginViewModel(
                        userService: serviceContainer.userService,
                        dataManager: dataManager
                    )
                )
                .transition(.opacity)
            }
        }
        .alert("Navigation Error", isPresented: $showNavigationError) {
            Button("OK") { }
        } message: {
            Text(navigationErrorMessage)
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

