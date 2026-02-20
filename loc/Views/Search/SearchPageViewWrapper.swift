//
//  SearchPageViewWrapper.swift
//  loc
//
//  Wrapper to manage SearchPageViewModel lifecycle for fullScreenCover
//

import SwiftUI

/// Wrapper view that manages SearchPageViewModel lifecycle
/// Single Responsibility: Create and configure SearchPageViewModel for fullScreenCover presentation
struct SearchPageViewWrapper: View {
    // MARK: - Dependencies

    let searchViewModel: SearchViewModel
    let searchCoordinator: SearchCoordinatorViewModel

    // MARK: - Bindings

    @Binding var showSearchPage: Bool

    // MARK: - Environment

    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator

    // MARK: - Body

    var body: some View {
        SearchPageViewContent(
            searchViewModel: searchViewModel,
            searchCoordinator: searchCoordinator,
            showSearchPage: $showSearchPage,
            userSession: userSession,
            userProfileNavigationViewModel: userProfileNavigationViewModel,
            appCoordinator: appCoordinator
        )
    }
}

/// Inner view that can create StateObject with proper dependencies
private struct SearchPageViewContent: View {
    // MARK: - Dependencies

    let searchViewModel: SearchViewModel
    let searchCoordinator: SearchCoordinatorViewModel
    let userSession: UserSession
    let userProfileNavigationViewModel: UserProfileNavigationViewModel
    let appCoordinator: AppCoordinator

    // MARK: - Bindings

    @Binding var showSearchPage: Bool

    // MARK: - ViewModel

    @StateObject private var viewModel: SearchPageViewModel

    // MARK: - Initialization

    init(
        searchViewModel: SearchViewModel,
        searchCoordinator: SearchCoordinatorViewModel,
        showSearchPage: Binding<Bool>,
        userSession: UserSession,
        userProfileNavigationViewModel: UserProfileNavigationViewModel,
        appCoordinator: AppCoordinator
    ) {
        self.searchViewModel = searchViewModel
        self.searchCoordinator = searchCoordinator
        self._showSearchPage = showSearchPage
        self.userSession = userSession
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
        self.appCoordinator = appCoordinator

        _viewModel = StateObject(wrappedValue: SearchPageViewModel(
            searchViewModel: searchViewModel,
            userSession: userSession,
            userProfileNavigationViewModel: userProfileNavigationViewModel
        ))
    }

    // MARK: - Body

    var body: some View {
        SearchPageView(viewModel: viewModel)
            .onAppear {
                viewModel.onDismiss = {
                    showSearchPage = false
                }

                viewModel.onPlaceSelected = { place in
                    // Set the place and start map animation FIRST (before any dismiss)
                    searchCoordinator.prepareMapForPlace(place)
                    searchCoordinator.presentPlaceDetail()

                    // Then dismiss search (no animation)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showSearchPage = false
                    }
                }

                viewModel.onUserSelected = { _ in
                    // Dismissal and navigation are handled by the ViewModel
                }

                viewModel.onViewAllKeywords = { keyword, types in
                    appCoordinator.keywordForPopup = keyword
                    appCoordinator.keywordTypesForPopup = types
                    appCoordinator.hasPendingKeywordPopup = true
                    showSearchPage = false
                }

                viewModel.onCoordinateSelected = { coordinate in
                    appCoordinator.coordinateForPlaceCreation = coordinate
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showSearchPage = false
                    }
                }

                // Set map region for viewport-based searches
                viewModel.setMapRegion(appCoordinator.currentMapRegion)
            }
    }
}
