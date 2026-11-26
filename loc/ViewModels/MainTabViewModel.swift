//
//  MainTabViewModel.swift
//  loc
//
//  Coordinates the tab bar over the always-present map: Explore and Trips are bottom sheets over
//  the map and Profile is a full page. Routes map-bound flows (opening a list or place, profile "show on map"
//  actions, external profile navigation, share-extension imports) by moving to the map; closing
//  that map content leaves the map showing, and closing an external profile brings the tab back.
//

import Foundation
import Combine

@MainActor
final class MainTabViewModel: ObservableObject {

    // MARK: - Dependencies

    let router = AppTabRouter.shared
    /// Height state of the tab sheet over the map.
    let tabSheet = TabSheetViewModel()
    private let presentationService = PresentationService.shared
    private let profileViewModel: ProfileViewModel
    private let userProfileNavigationViewModel: UserProfileNavigationViewModel
    private let mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    private let deepLinkViewModel: DeepLinkViewModel
    private let selectedPlaceViewModel: SelectedPlaceViewModel
    private let userSession: UserSession
    private var cancellables = Set<AnyCancellable>()
    private var previousTab: AppTab = .map
    private var sawMapSheet = false
    private var restoreTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates the coordinator and starts observing the flows that change the selected tab.
    init(
        profileViewModel: ProfileViewModel,
        userProfileNavigationViewModel: UserProfileNavigationViewModel,
        mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel,
        deepLinkViewModel: DeepLinkViewModel,
        selectedPlaceViewModel: SelectedPlaceViewModel,
        userSession: UserSession
    ) {
        self.mapDisplayCoordinatorViewModel = mapDisplayCoordinatorViewModel
        self.profileViewModel = profileViewModel
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
        self.deepLinkViewModel = deepLinkViewModel
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.userSession = userSession
        observeProfileHandoff()
        observeProfileNavigation()
        observeMapBoundFlows()
        observeTabSelection()
        observeMapSheetClosing()
        observeTripOnMap()
        observeTabListPins()
    }

    // MARK: - Opening Content From Other Tabs

    /// Collapses the tab sheet and opens the place's detail sheet over the map.
    func openPlaceOnMap(placeId: String) {
        router.handOffToMap { [selectedPlaceViewModel] in
            selectedPlaceViewModel.navigateToPlace(placeId: placeId)
        }
    }

    /// Collapses the tab sheet, flies to the place, and opens its detail sheet.
    func openPlaceOnMap(_ place: DetailPlace) {
        router.handOffToMap { [selectedPlaceViewModel] in
            selectedPlaceViewModel.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
            PresentationService.shared.transition(to: .placeDetail)
        }
    }

    /// Opens another user's profile (hosted by the Map tab's navigation stack).
    func openUserProfile(userId: String) {
        guard let currentUserId = userSession.currentUserId else { return }
        if userId == currentUserId {
            router.select(.profile)
        } else {
            userProfileNavigationViewModel.fetchAndSelectUser(userId: userId, currentUserId: currentUserId)
        }
    }

    // MARK: - Observation

    /// Watches the profile's "show this on the map" requests and hands them to the Map tab.
    private func observeProfileHandoff() {
        let requests = Publishers.Merge3(
            profileViewModel.$selectedListIdForMap.map { $0 != nil },
            profileViewModel.$pendingSheet.map { $0 != nil },
            profileViewModel.$pendingMapFilter.map { $0 != nil }
        )
        requests
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handOffProfileRequestToMap() }
            .store(in: &cancellables)
    }

    /// Routes "open my own profile" requests (tapping yourself anywhere) to the Profile tab.
    private func observeProfileNavigation() {
        userProfileNavigationViewModel.$shouldNavigateToOwnProfile
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.router.select(.profile)
                self?.userProfileNavigationViewModel.clearOwnProfileNavigation()
            }
            .store(in: &cancellables)
    }

    /// Routes external-profile navigation (returning to the tab sheet afterwards) and deep-link processing to the Map tab, which hosts both.
    private func observeMapBoundFlows() {
        userProfileNavigationViewModel.$isUserDetailPresented
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isPresented in self?.externalProfilePresenceChanged(isPresented) }
            .store(in: &cancellables)

        deepLinkViewModel.$isProcessingDeepLink
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.router.select(.map) }
            .store(in: &cancellables)
    }

    // MARK: - Profile → Map handoff

    /// Moves from the Profile page to the map and then applies the profile's pending map action.
    private func handOffProfileRequestToMap() {
        // Requests raised while already on the map (e.g. import progress) are handled by the map itself.
        guard router.selected == .profile else { return }
        router.handOffToMap { [weak self] in self?.applyPendingProfileAction() }
    }

    /// Presents the sheet, list, or map filter the profile asked for, in that order of priority.
    private func applyPendingProfileAction() {
        if let sheet = profileViewModel.pendingSheet {
            profileViewModel.pendingSheet = nil
            PresentationService.shared.present(sheet)
        } else if let listId = profileViewModel.selectedListIdForMap {
            PresentationService.shared.present(.list(listId: listId))
        } else if let pending = profileViewModel.pendingMapFilter {
            profileViewModel.pendingMapFilter = nil
            // A filter has no sheet whose closing would bring the profile back.
            router.clearReturnTab()
            applyMapFilter(pending)
        }
    }

    /// Turns on the map overlay matching the profile's pending filter.
    private func applyMapFilter(_ filter: ProfileViewModel.PendingMapFilter) {
        switch filter {
        case .externalPlaces: profileViewModel.showExternalPlacesOnMap = true
        case .reviews: profileViewModel.showReviewsOnMap = true
        case .favorites: profileViewModel.showFavoritesOnMap = true
        case .myPlaces: profileViewModel.showMyPlacesOnMap = true
        }
    }

    // MARK: - Tab Sheet Behavior

    /// Opens a tab sheet at its large height whenever it is raised from the map or the Profile page.
    private func observeTabSelection() {
        router.$selected
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] tab in
                guard let self else { return }
                if tab.isSheet && !self.previousTab.isSheet { self.tabSheet.presentAtLarge() }
                self.previousTab = tab
            }
            .store(in: &cancellables)
    }

    /// Watches the map's sheet slot: once content opened from a tab closes, the map stays on screen by itself.
    private func observeMapSheetClosing() {
        presentationService.$activeSheet
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] hasSheet in self?.mapSheetPresenceChanged(hasSheet) }
            .store(in: &cancellables)
    }

    /// Cancels a pending settle while a sheet is up and schedules one when the last sheet has gone.
    private func mapSheetPresenceChanged(_ hasSheet: Bool) {
        if hasSheet {
            sawMapSheet = true
            restoreTask?.cancel()
            return
        }
        guard sawMapSheet else { return }
        sawMapSheet = false
        restoreTask?.cancel()
        restoreTask = Task { @MainActor [weak self] in
            // Sheet-to-sheet swaps pass through "no sheet"; only restore if nothing else shows up.
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self, !Task.isCancelled else { return }
            self.settleOnMapIfIdle()
        }
    }

    /// Leaves the user on the map (tab sheet stays hidden) once the content opened from a tab has been dismissed.
    private func settleOnMapIfIdle() {
        guard presentationService.activeSheet == nil, presentationService.preservedSheet == nil else { return }
        router.clearReturnTab()
    }

    /// Brings the originating tab sheet back unless a sheet, an external profile or a preserved sheet is taking over.
    private func restoreTabSheetIfMapIsIdle() {
        guard presentationService.activeSheet == nil,
              presentationService.preservedSheet == nil,
              !userProfileNavigationViewModel.isUserDetailPresented else { return }
        router.restoreReturnTab()
    }

    /// Hands the external-profile page (hosted by the map) the screen, and returns to the tab sheet when it closes.
    private func externalProfilePresenceChanged(_ isPresented: Bool) {
        if isPresented {
            sawMapSheet = false
            router.handOffToMap {}
        } else {
            restoreTabSheetIfMapIsIdle()
        }
    }

    /// Lowers the Trips sheet to medium when a trip is shown on the map so its route and pins are visible, and restores it when the trip is cleared.
    private func observeTripOnMap() {
        mapDisplayCoordinatorViewModel.$activeTripId
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] tripId in
                guard let self else { return }
                if tripId == nil {
                    self.tabSheet.restoreFromLowered()
                } else if self.router.selected == .trips {
                    self.tabSheet.lowerToMedium()
                }
            }
            .store(in: &cancellables)
    }

    /// Lowers the Explore sheet to medium while a list is pushed (its pins show on the map) and restores it when the list is popped.
    private func observeTabListPins() {
        mapDisplayCoordinatorViewModel.$tabListPins
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] hasPins in
                guard let self else { return }
                if !hasPins {
                    self.tabSheet.restoreFromLowered()
                } else if self.router.selected == .explore {
                    self.tabSheet.lowerToMedium()
                }
            }
            .store(in: &cancellables)
    }
}
