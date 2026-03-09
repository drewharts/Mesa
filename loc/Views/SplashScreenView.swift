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

    var body: some View {
        Group {
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
                .transition(.opacity)
            } else {
                splashImage
            }
        }
        .task {
            await viewModel.checkSessionAndTransition()
        }
    }

    private var splashImage: some View {
        GeometryReader { geometry in
            Image("SplashScreen")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .edgesIgnoringSafeArea(.all)
    }
}
