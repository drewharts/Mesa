//
//  ExternalUserProfileViewWrapper.swift
//  loc
//
//  A wrapper that creates the @StateObject ViewModel for Instagram-style nested profile navigation.
//  Each profile in the navigation stack owns its own independent ViewModel instance.
//

import SwiftUI

/// Wrapper view that owns the @StateObject for ExternalUserProfileViewModel.
/// This enables each profile in the navigation stack to maintain independent state.
struct ExternalUserProfileViewWrapper: View {
    let user: ProfileData
    let pendingListId: String?

    @StateObject private var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var dataManager: DataManager

    /// Creates a wrapper for an external user profile.
    /// - Parameters:
    ///   - user: The user profile data to display
    ///   - pendingListId: Optional list ID to auto-open (for deep link navigation)
    init(user: ProfileData, pendingListId: String? = nil) {
        self.user = user
        self.pendingListId = pendingListId
        self._viewModel = StateObject(wrappedValue: ExternalUserProfileViewModel(user: user, pendingListId: pendingListId))
    }

    var body: some View {
        ExternalUserProfileContentView(viewModel: viewModel)
            .environmentObject(profileVM)
            .environmentObject(detailPlaceVM)
            .environmentObject(userSession)
            .environmentObject(selectedPlaceVM)
            .environmentObject(userProfileNavigationVM)
            .environmentObject(mapDisplayCoordinatorVM)
            .environmentObject(locationManager)
            .environmentObject(dataManager)
            .task {
                guard let currentUserId = userSession.currentUserId else { return }
                // Set location manager for proximity-based list sorting
                viewModel.setLocationManager(locationManager)
                await viewModel.loadInitialData(currentUserId: currentUserId)
            }
    }
}
