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
    let searchViewModel: SearchViewModel
    let searchCoordinator: SearchCoordinatorViewModel

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
            .opacity(userSession.isUserLoggedIn && !userSession.needsProfilePhoto && !userSession.needsListOnboarding ? 1 : 0)
            .allowsHitTesting(userSession.isUserLoggedIn && !userSession.needsProfilePhoto && !userSession.needsListOnboarding)
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

            // Profile photo onboarding overlays after login but before main app
            if userSession.isUserLoggedIn && userSession.needsProfilePhoto {
                ProfilePhotoOnboardingView(userId: userSession.currentUserId ?? "")
                    .transition(.opacity)
            }

            // List creation onboarding overlays after photo onboarding but before main app
            if userSession.isUserLoggedIn && !userSession.needsProfilePhoto && userSession.needsListOnboarding {
                ListOnboardingView()
                    .transition(.opacity)
            }
        }
        .alert("Navigation Error", isPresented: $showNavigationError) {
            Button("OK") { }
        } message: {
            Text(navigationErrorMessage)
        }
        .onChange(of: userSession.needsProfilePhoto) { oldValue, newValue in
            // When photo onboarding completes, refresh profile data
            if oldValue && !newValue {
                if let userId = userSession.currentUserId {
                    Task {
                        await dataManager.loadProfileData(userId: userId)
                    }
                }
            }
        }
        .onChange(of: userSession.needsListOnboarding) { oldValue, newValue in
            // When list onboarding completes, reload profile data and show suggested profiles
            if oldValue && !newValue {
                if let userId = userSession.currentUserId {
                    Task {
                        await dataManager.loadProfileData(userId: userId)
                    }
                }
                if SuggestedProfilesViewModel.shouldShowPopup {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        PresentationService.shared.present(.suggestedProfiles)
                    }
                }
            }
        }
        .onChange(of: userSession.isUserLoggedIn) { oldValue, newValue in
            // Show suggested profiles on login only if all onboarding is already complete
            if !oldValue && newValue && !userSession.needsProfilePhoto && !userSession.needsListOnboarding && SuggestedProfilesViewModel.shouldShowPopup {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    PresentationService.shared.present(.suggestedProfiles)
                }
            }
        }
    }
    
    /// Processes a pending notification navigation by fetching the place and presenting its detail sheet.
    private func handleNotificationNavigation(_ pendingNavigation: PendingNavigation?) {
        guard let navigation = pendingNavigation else { return }

        guard userSession.isUserLoggedIn, userSession.currentUserId != nil else {
            notificationManager.clearPendingNavigation()
            notificationManager.clearHighlightedReview()
            return
        }

        serviceContainer.placeService.fetchPlace(withId: navigation.placeId) { result in
            switch result {
            case .success(let place):
                selectedPlaceViewModel.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
                selectedPlaceViewModel.isDetailSheetPresented = true
                notificationManager.clearPendingNavigation()
            case .failure:
                navigationErrorMessage = "Sorry, we couldn't find that place. It may have been removed."
                showNavigationError = true
                notificationManager.clearPendingNavigation()
                notificationManager.clearHighlightedReview()
            }
        }
    }
}

