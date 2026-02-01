//
//  SearchPageView.swift
//  loc
//
//  Full-screen search page (Google Maps style)
//

import SwiftUI

/// Full-screen search page view
/// Single Responsibility: Container for search UI with NavigationStack for user profiles
struct SearchPageView: View {
    // MARK: - ViewModel

    @ObservedObject var viewModel: SearchPageViewModel

    // MARK: - Focus State

    @FocusState private var isSearchFocused: Bool

    // MARK: - Environment

    @EnvironmentObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var dataManager: DataManager

    // MARK: - Computed Properties

    /// Binding to searchText through the ViewModel chain
    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchViewModel.searchText },
            set: { viewModel.searchViewModel.searchText = $0 }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchHeaderView(
                    searchText: searchTextBinding,
                    isFocused: $isSearchFocused,
                    onCancel: handleCancel
                )

                SearchContentView(
                    searchViewModel: viewModel.searchViewModel,
                    onSelectPlace: handlePlaceSelection,
                    onSelectUser: handleUserSelection,
                    onViewAllKeywords: viewModel.handleViewAllKeywords
                )
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $userProfileNavigationViewModel.isUserDetailPresented) {
                if let selectedUser = userProfileNavigationViewModel.selectedUser {
                    ExternalUserProfileViewWrapper(
                        user: selectedUser,
                        pendingListId: userProfileNavigationViewModel.pendingListIdToOpen
                    )
                    .environmentObject(profileViewModel)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(detailPlaceViewModel)
                    .environmentObject(userSession)
                    .environmentObject(userProfileNavigationViewModel)
                    .environmentObject(mapDisplayCoordinatorViewModel)
                    .environmentObject(locationManager)
                    .environmentObject(dataManager)
                }
            }
        }
        .onAppear {
            viewModel.searchViewModel.setupIfNeeded()
            viewModel.searchViewModel.searchText = ""
            isSearchFocused = true
        }
    }

    // MARK: - Actions

    /// Dismiss the search page
    private func handleCancel() {
        isSearchFocused = false
        viewModel.dismiss()
    }

    /// Handle place selection - dismiss and navigate to place
    private func handlePlaceSelection(_ place: DetailPlace) {
        isSearchFocused = false
        viewModel.handlePlaceSelection(place)
        viewModel.dismiss()
    }

    /// Handle user selection - navigate within search NavigationStack
    private func handleUserSelection(_ user: ProfileData) {
        isSearchFocused = false
        viewModel.handleUserSelection(user)
    }
}
