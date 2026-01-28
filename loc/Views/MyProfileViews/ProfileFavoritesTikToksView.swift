//
//  ProfileFavoritesTikToksView.swift
//  loc
//
//  Displays the Favorites, TikToks, and Reviews tabs for the current user's profile.
//  Uses shared ProfileFavoritesReviewsSection component for consistent UI.
//

import SwiftUI

struct ProfileFavoritesTikToksView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var showingTikToksPopup = false
    @State private var showingReviewsPopup = false
    @State private var showingHelpSheet = false

    // MARK: - Computed Properties

    /// Data source for the shared section component.
    private var sectionData: ProfileFavoritesReviewsSectionData {
        ProfileFavoritesReviewsSectionData(
            favorites: profile.lightweightFavorites,
            tiktokPlaces: profile.lightweightExternalPlaces,
            reviewedPlaces: profile.lightweightReviewedPlaces,
            isLoadingTikToks: profile.isLoadingTikTokPlaces,
            isLoadingReviews: profile.isLoadingReviewedPlaces
        )
    }

    // MARK: - Body

    var body: some View {
        ProfileFavoritesReviewsSection(
            data: sectionData,
            config: .myProfile,
            onFavoritesTap: handleFavoritesTap,
            onTikToksTap: handleTikToksTap,
            onReviewsTap: handleReviewsTap,
            onTikTokHelpTap: { showingHelpSheet = true }
        )
        .sheet(isPresented: $showingTikToksPopup) {
            TikToksPopupView()
        }
        .sheet(isPresented: $showingReviewsPopup) {
            ReviewsListPopupView()
        }
        .sheet(isPresented: $showingHelpSheet) {
            TikTokImportHelpView()
        }
    }

    // MARK: - Actions

    /// Handles tap on favorites section - navigates to map.
    private func handleFavoritesTap() {
        profile.showFavoritesOnMap = true
        presentationMode.wrappedValue.dismiss()
    }

    /// Handles tap on TikToks section - navigates to map.
    private func handleTikToksTap() {
        profile.showTikToksOnMap = true
        presentationMode.wrappedValue.dismiss()
    }

    /// Handles tap on reviews section - navigates to map.
    private func handleReviewsTap() {
        profile.showReviewsOnMap = true
        presentationMode.wrappedValue.dismiss()
    }
}
