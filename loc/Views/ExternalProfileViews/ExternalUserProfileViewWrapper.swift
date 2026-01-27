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

    @StateObject private var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    init(user: ProfileData) {
        self.user = user
        self._viewModel = StateObject(wrappedValue: ExternalUserProfileViewModel(user: user))
    }

    var body: some View {
        ExternalUserProfileContentView(viewModel: viewModel)
            .environmentObject(profileVM)
            .environmentObject(detailPlaceVM)
            .environmentObject(userSession)
            .environmentObject(selectedPlaceVM)
            .task {
                guard let currentUserId = userSession.currentUserId else { return }
                await viewModel.loadInitialData(currentUserId: currentUserId)
            }
    }
}
