//
//  MainTabView.swift
//  loc
//
//  Root container: the map is always the base layer. Explore, Trips and Profile are presented as a
//  bottom sheet over the map with the tab bar staying visible; selecting Map lowers the sheet away.
//  Each tab keeps its own NavigationStack and state; map sheets (lists, places) sit above the bar.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject private var router = AppTabRouter.shared
    @StateObject private var viewModel: MainTabViewModel
    @StateObject private var profileIconViewModel: ProfileTabIconViewModel

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
        self._profileIconViewModel = StateObject(wrappedValue: ProfileTabIconViewModel(profileViewModel: profileViewModel))
        self._viewModel = StateObject(wrappedValue: MainTabViewModel(
            profileViewModel: profileViewModel,
            userProfileNavigationViewModel: userProfileNavigationViewModel,
            mapDisplayCoordinatorViewModel: mapDisplayCoordinatorViewModel,
            deepLinkViewModel: deepLinkViewModel,
            selectedPlaceViewModel: selectedPlaceVM,
            userSession: userSession
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                mapTab
                TabSheetContainer(viewModel: viewModel.tabSheet, isPresented: router.selected != .map) {
                    tabSheetContent
                }
            }
            AppTabBar(
                selected: router.selected,
                profileIcon: profileIconViewModel.normalIcon,
                selectedProfileIcon: profileIconViewModel.selectedIcon,
                onSelect: { router.select($0) }
            )
        }
        .tint(.mesaAccent)
    }

    // MARK: - Tabs

    /// Explore, Trips and Profile content, created on first visit and kept alive (hidden) afterwards.
    private var tabSheetContent: some View {
        ZStack {
            if router.visitedTabs.contains(.explore) {
                exploreTab.tabLayer(isActive: router.selected == .explore)
            }
            if router.visitedTabs.contains(.trips) {
                tripsTab.tabLayer(isActive: router.selected == .trips)
            }
            if router.visitedTabs.contains(.profile) {
                profileTab.tabLayer(isActive: router.selected == .profile)
            }
        }
    }

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
            onOpenList: { viewModel.openListOnMap($0) },
            onOpenListFindTable: { viewModel.openListOnMap($0, startFindTable: true) },
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
