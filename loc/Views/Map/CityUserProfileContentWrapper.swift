//
//  CityUserProfileContentWrapper.swift
//  loc
//
//  Inner wrapper that creates ExternalUserProfileViewModel once ProfileData is available,
//  then renders ExternalUserProfileContentView within the city sheet's NavigationStack.
//

import SwiftUI

/// Creates ExternalUserProfileViewModel and renders the external profile content.
struct CityUserProfileContentWrapper: View {
    let user: ProfileData
    @StateObject private var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager

    init(user: ProfileData) {
        self.user = user
        self._viewModel = StateObject(wrappedValue: ExternalUserProfileViewModel(user: user))
    }

    var body: some View {
        ExternalUserProfileContentView(viewModel: viewModel)
            .task {
                guard let currentUserId = userSession.currentUserId else { return }
                viewModel.setLocationManager(locationManager)
                await viewModel.loadInitialData(currentUserId: currentUserId)
            }
    }
}
