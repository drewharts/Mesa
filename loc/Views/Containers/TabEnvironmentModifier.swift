//
//  TabEnvironmentModifier.swift
//  loc
//
//  Injects the shared app ViewModels into a tab's root so each tab (and anything it pushes or
//  presents) resolves the same environment objects the Map tab's sheets always had.
//

import SwiftUI

/// Supplies the shared app-level ViewModels and services to a tab's content.
struct TabEnvironmentModifier: ViewModifier {
    let selectedPlaceViewModel: SelectedPlaceViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let profileViewModel: ProfileViewModel
    let userProfileNavigationViewModel: UserProfileNavigationViewModel
    let mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    let deepLinkViewModel: DeepLinkViewModel
    let deepLinkManager: DeepLinkManager
    let notificationManager: NotificationManager
    let dataManager: DataManager
    let serviceContainer: ServiceContainer

    func body(content: Content) -> some View {
        content
            .environmentObject(selectedPlaceViewModel)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(profileViewModel)
            .environmentObject(userProfileNavigationViewModel)
            .environmentObject(mapDisplayCoordinatorViewModel)
            .environmentObject(deepLinkViewModel)
            .environmentObject(deepLinkManager)
            .environmentObject(notificationManager)
            .environmentObject(dataManager)
            .environmentObject(serviceContainer)
    }
}
