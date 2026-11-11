//
//  ExternalUserProfileFavoritesReviewsView.swift
//  loc
//
//  Reviews tab for external user profiles (Favorites was removed from profiles; UI only).
//  Uses shared ProfileFavoritesReviewsSection component for consistent UI.
//

import SwiftUI

/// Tab selection for external user profile (no external places tab).
enum UserFavoritesReviewsTab: String, CaseIterable {
    case favorites = "FAVORITES"
    case reviews = "REVIEWS"
}

struct ExternalUserProfileFavoritesReviewsView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @EnvironmentObject var userSession: UserSession

    @State private var showReviewsPopup = false

    // MARK: - Computed Properties

    /// Data source for the shared section component.
    private var sectionData: ProfileFavoritesReviewsSectionData {
        ProfileFavoritesReviewsSectionData(
            favorites: viewModel.userFavorites,
            externalPlaces: [],  // External profiles don't show external places tab
            reviewedPlaces: viewModel.lightweightReviewedPlaces,
            myPlaces: [],  // External profiles don't show My Places tab
            isLoadingExternalPlaces: false,
            isLoadingReviews: viewModel.isLoadingReviewedPlaces,
            isLoadingMyPlaces: false,
            isLoadingFavorites: viewModel.isLoadingFavorites
        )
    }

    /// Configuration for external profile (no external places tab).
    private var sectionConfig: ProfileFavoritesReviewsSectionConfig {
        .external(ownerName: viewModel.user.firstName)
    }

    // MARK: - Body

    var body: some View {
        ProfileFavoritesReviewsSection(
            data: sectionData,
            config: sectionConfig,
            onFavoritesTap: {},  // Favorites tab is hidden on profiles
            onExternalPlacesTap: nil,  // No external places tab for external profiles
            onReviewsTap: { showReviewsPopup = true },
            onMyPlacesTap: nil,  // No My Places tab for external profiles
            onExternalPlacesHelpTap: nil
        )
        .sheet(isPresented: $showReviewsPopup) {
            ProfileReviewsPopupView(viewModel: viewModel)
                .environmentObject(selectedPlaceVM)
                .environmentObject(profileVM)
                .environmentObject(locationManager)
                .environmentObject(userProfileNavigationVM)
                .environmentObject(mapDisplayCoordinatorVM)
                .environmentObject(userSession)
                .environmentObject(detailPlaceViewModel)
        }
        .onAppear {
            loadDataIfNeeded()
        }
    }

    // MARK: - Data Loading

    /// Loads reviewed places data if needed.
    private func loadDataIfNeeded() {
        if viewModel.lightweightReviewedPlaces.isEmpty && !viewModel.isLoadingReviewedPlaces {
            Task {
                await viewModel.loadUserReviewedPlacesWithPagination()
            }
        }
    }
}
