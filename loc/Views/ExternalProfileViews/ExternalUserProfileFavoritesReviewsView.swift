//
//  ExternalUserProfileFavoritesReviewsView.swift
//  loc
//
//  Favorites and Reviews tabs for external user profiles.
//  Uses shared ProfileFavoritesReviewsSection component for consistent UI.
//

import SwiftUI

/// Tab selection for external user profile (no TikToks tab).
enum UserFavoritesReviewsTab: String, CaseIterable {
    case favorites = "FAVORITES"
    case reviews = "REVIEWS"
}

struct ExternalUserProfileFavoritesReviewsView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    @State private var showFavoritesPopup = false
    @State private var showReviewsPopup = false
    @State private var hasSetInitialTab: Bool = false

    // MARK: - Computed Properties

    /// Data source for the shared section component.
    private var sectionData: ProfileFavoritesReviewsSectionData {
        ProfileFavoritesReviewsSectionData(
            favorites: viewModel.userFavorites,
            tiktokPlaces: [],  // External profiles don't show TikToks tab
            reviewedPlaces: viewModel.lightweightReviewedPlaces,
            isLoadingTikToks: false,
            isLoadingReviews: viewModel.isLoadingReviewedPlaces
        )
    }

    /// Configuration for external profile (no TikToks tab).
    private var sectionConfig: ProfileFavoritesReviewsSectionConfig {
        .external(ownerName: viewModel.user.firstName)
    }

    // MARK: - Body

    var body: some View {
        ProfileFavoritesReviewsSection(
            data: sectionData,
            config: sectionConfig,
            onFavoritesTap: { showFavoritesPopup = true },
            onTikToksTap: nil,  // No TikToks tab for external profiles
            onReviewsTap: { showReviewsPopup = true },
            onTikTokHelpTap: nil
        )
        .sheet(isPresented: $showFavoritesPopup) {
            ProfileFavoritesPopupView(viewModel: viewModel)
                .environmentObject(selectedPlaceVM)
        }
        .sheet(isPresented: $showReviewsPopup) {
            ProfileReviewsPopupView(viewModel: viewModel)
                .environmentObject(selectedPlaceVM)
        }
        .onAppear {
            loadDataIfNeeded()
        }
        .onChange(of: viewModel.isLoadingFavorites) { _, isLoading in
            handleFavoritesLoadingChange(isLoading: isLoading)
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

    /// Handles initial tab selection when favorites finish loading.
    private func handleFavoritesLoadingChange(isLoading: Bool) {
        if !isLoading && !hasSetInitialTab {
            hasSetInitialTab = true
            // Note: Tab selection is now handled internally by ProfileFavoritesReviewsSection
        }
    }
}
