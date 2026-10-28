//
//  SplashScreenView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//  Refactored to enterprise architecture on 11/13/25
//

import SwiftUI

struct SplashScreenView: View {
    @ObservedObject var viewModel: SplashScreenViewModel

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

    @State private var introFinished = false

    var body: some View {
        ZStack {
            // The app mounts underneath as soon as the session is ready; the intro never gates it.
            if viewModel.isActive {
                ContentView(
                    selectedPlaceViewModel: selectedPlaceViewModel,
                    profileViewModel: profileViewModel,
                    userProfileNavigationViewModel: userProfileNavigationViewModel,
                    mapDisplayCoordinatorViewModel: mapDisplayCoordinatorViewModel,
                    detailPlaceViewModel: detailPlaceViewModel,
                    deepLinkViewModel: deepLinkViewModel,
                    deepLinkManager: deepLinkManager,
                    notificationManager: notificationManager,
                    dataManager: dataManager,
                    serviceContainer: serviceContainer,
                    searchViewModel: searchViewModel,
                    searchCoordinator: searchCoordinator
                )
            }
            // Stays up until BOTH the intro finished and the app is ready, then fades/zooms away.
            if !(viewModel.isActive && introFinished) {
                AnimatedSplashView { introFinished = true }
                    .transition(.asymmetric(insertion: .identity,
                                            removal: .opacity.combined(with: .scale(scale: 1.06))))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isActive && introFinished)
        .task {
            await viewModel.checkSessionAndTransition()
        }
    }
}
