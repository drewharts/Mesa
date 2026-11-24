//
//  MainTabViewModel.swift
//  loc
//
//  Coordinates the bottom tab bar: routes map-bound flows (profile "show on map" actions,
//  external profile navigation, share-extension imports) to the Map tab and sends
//  "open my profile" requests to the Profile tab.
//

import Foundation
import Combine

@MainActor
final class MainTabViewModel: ObservableObject {

    // MARK: - Dependencies

    let router = AppTabRouter.shared
    private let profileViewModel: ProfileViewModel
    private let userProfileNavigationViewModel: UserProfileNavigationViewModel
    private let deepLinkViewModel: DeepLinkViewModel
    private let selectedPlaceViewModel: SelectedPlaceViewModel
    private let userSession: UserSession
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates the coordinator and starts observing the flows that change the selected tab.
    init(
        profileViewModel: ProfileViewModel,
        userProfileNavigationViewModel: UserProfileNavigationViewModel,
        deepLinkViewModel: DeepLinkViewModel,
        selectedPlaceViewModel: SelectedPlaceViewModel,
        userSession: UserSession
    ) {
        self.profileViewModel = profileViewModel
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
        self.deepLinkViewModel = deepLinkViewModel
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.userSession = userSession
        observeProfileHandoff()
        observeProfileNavigation()
        observeMapBoundFlows()
    }

    // MARK: - Opening Content From Other Tabs

    /// Switches to the Map tab and opens the place's detail sheet.
    func openPlaceOnMap(placeId: String) {
        router.select(.map) { [selectedPlaceViewModel] in
            selectedPlaceViewModel.navigateToPlace(placeId: placeId)
        }
    }

    /// Switches to the Map tab, flies to the place, and opens its detail sheet.
    func openPlaceOnMap(_ place: DetailPlace) {
        router.select(.map) { [selectedPlaceViewModel] in
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

    /// Routes external-profile navigation and deep-link processing to the Map tab, which hosts both.
    private func observeMapBoundFlows() {
        userProfileNavigationViewModel.$isUserDetailPresented
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.router.select(.map) }
            .store(in: &cancellables)

        deepLinkViewModel.$isProcessingDeepLink
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.router.select(.map) }
            .store(in: &cancellables)
    }

    // MARK: - Profile → Map handoff

    /// Switches from the Profile tab to the Map tab and then applies the profile's pending map action.
    private func handOffProfileRequestToMap() {
        // Requests raised while already on the map (e.g. import progress) are handled by the map itself.
        guard router.selected == .profile else { return }
        router.select(.map)
        Task { @MainActor [weak self] in
            // Let the map tab finish appearing so the sheet is not dropped mid-transition.
            try? await Task.sleep(nanoseconds: 400_000_000)
            self?.applyPendingProfileAction()
        }
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
}
