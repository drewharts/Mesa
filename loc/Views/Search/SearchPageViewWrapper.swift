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
                    // Start map animation immediately (runs parallel to search dismiss)
                    searchCoordinator.prepareMapForPlace(place)

                    // Dismiss search page
                    showSearchPage = false

                    // Present detail sheet after dismiss animation starts (avoids iOS sheet conflict)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        searchCoordinator.presentPlaceDetail()
                    }
                }

                viewModel.onUserSelected = { _ in
                    // User selection navigates within search NavigationStack
                    // Don't dismiss - let user navigate back
                }

                viewModel.onViewAllKeywords = { keyword, types in
                    print("🔍 [SearchPageViewWrapper] onViewAllKeywords callback triggered")
                    print("   - keyword: \(keyword)")
                    print("   - types: \(types)")
                    showSearchPage = false
                    appCoordinator.triggerKeywordResultsPopup(keyword: keyword, types: types)
                    print("   ✅ triggerKeywordResultsPopup called")
                }

                // Set map region for viewport-based searches
                viewModel.setMapRegion(appCoordinator.currentMapRegion)
            }
    }
}
