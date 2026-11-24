//
//  MainTabView.swift
//  loc
//
//  Native bottom tab bar: Map (home), Explore, Trips, Profile. Each tab keeps its own
//  NavigationStack and state; map sheets are presented by the Map tab and sit above the bar.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject private var router = AppTabRouter.shared
    @StateObject private var viewModel: MainTabViewModel

    let selectedPlaceVM: SelectedPlaceViewModel
    let profileViewModel: ProfileViewModel
    let userProfileNavigationViewModel: UserProfileNavigationViewModel
    let mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let deepLinkViewModel: DeepLinkViewModel
    let notificationManager: NotificationManager
    let searchViewModel: SearchViewModel
    let searchCoordinator: SearchCoordinatorViewModel
    let deepLinkManager: DeepLinkManager
    let dataManager: DataManager
    let serviceContainer: ServiceContainer

    /// Creates the tab container and its coordinating ViewModel.
    init(
        selectedPlaceVM: SelectedPlaceViewModel,
        profileViewModel: ProfileViewModel,
        userProfileNavigationViewModel: UserProfileNavigationViewModel,
        mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel,
        detailPlaceViewModel: DetailPlaceViewModel,
        deepLinkViewModel: DeepLinkViewModel,
        notificationManager: NotificationManager,
        searchViewModel: SearchViewModel,
        searchCoordinator: SearchCoordinatorViewModel,
        deepLinkManager: DeepLinkManager,
        dataManager: DataManager,
        serviceContainer: ServiceContainer,
        userSession: UserSession
    ) {
        self.selectedPlaceVM = selectedPlaceVM
        self.profileViewModel = profileViewModel
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
        self.mapDisplayCoordinatorViewModel = mapDisplayCoordinatorViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
        self.deepLinkViewModel = deepLinkViewModel
        self.notificationManager = notificationManager
        self.searchViewModel = searchViewModel
        self.searchCoordinator = searchCoordinator
        self.deepLinkManager = deepLinkManager
        self.dataManager = dataManager
        self.serviceContainer = serviceContainer
        self._viewModel = StateObject(wrappedValue: MainTabViewModel(
            profileViewModel: profileViewModel,
            userProfileNavigationViewModel: userProfileNavigationViewModel,
            deepLinkViewModel: deepLinkViewModel,
            selectedPlaceViewModel: selectedPlaceVM,
            userSession: userSession
        ))
    }

    var body: some View {
        TabView(selection: $router.selected) {
            mapTab
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)

            exploreTab
                .tabItem { Label("Explore", systemImage: "safari") }
                .tag(AppTab.explore)

            tripsTab
                .tabItem { Label("Trips", systemImage: "airplane") }
                .tag(AppTab.trips)

            profileTab
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(.mesaAccent)
    }

    // MARK: - Tabs

    private var mapTab: some View {
        MainView(
            selectedPlaceVM: selectedPlaceVM,
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
    }

    private var exploreTab: some View {
        ExploreTabView(
            onOpenPlace: { viewModel.openPlaceOnMap(placeId: $0) },
            onOpenPlaceDetail: { viewModel.openPlaceOnMap($0) },
            onOpenUser: { viewModel.openUserProfile(userId: $0) }
        )
        .modifier(tabEnvironment)
    }

    private var tripsTab: some View {
        TripsListView(showsCloseButton: false)
            .modifier(tabEnvironment)
    }

    private var profileTab: some View {
        ProfileView(showsBackButton: false)
            .modifier(tabEnvironment)
    }

    private var tabEnvironment: TabEnvironmentModifier {
        TabEnvironmentModifier(
            selectedPlaceViewModel: selectedPlaceVM,
            detailPlaceViewModel: detailPlaceViewModel,
            profileViewModel: profileViewModel,
            userProfileNavigationViewModel: userProfileNavigationViewModel,
            mapDisplayCoordinatorViewModel: mapDisplayCoordinatorViewModel,
            deepLinkViewModel: deepLinkViewModel,
            deepLinkManager: deepLinkManager,
            notificationManager: notificationManager,
            dataManager: dataManager,
            serviceContainer: serviceContainer
        )
    }
}
