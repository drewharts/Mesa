//
//  ProfileFavoritesTikToksView.swift
//  loc
//
//  Displays the Favorites, TikToks, Reviews, and My Places sections for the current user's profile.
//  Tapping a section shows a popup sheet over the profile. A "View on Map" button in the popup
//  transitions to the map-layer sheet presentation.
//

import SwiftUI

/// Identifies which popup sheet is currently presented over the profile.
enum ProfilePopupSheet: String, Identifiable {
    case myPlaces, favorites, tiktoks, reviews, help
    var id: String { rawValue }
}

struct ProfileFavoritesTikToksView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var favoritesVM: ProfileFavoritesViewModel
    @ObservedObject var tikTokVM: ProfileTikTokViewModel
    @ObservedObject var reviewsVM: ProfileReviewsViewModel
    @ObservedObject var myPlacesVM: ProfileMyPlacesViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var activePopupSheet: ProfilePopupSheet? = nil
    @State private var pendingMapNavigation: ProfilePopupSheet? = nil

    // MARK: - Computed Properties

    /// Data source for the shared section component.
    private var sectionData: ProfileFavoritesReviewsSectionData {
        ProfileFavoritesReviewsSectionData(
            favorites: favoritesVM.lightweightFavorites,
            tiktokPlaces: tikTokVM.lightweightExternalPlaces,
            reviewedPlaces: reviewsVM.lightweightReviewedPlaces,
            myPlaces: myPlacesVM.lightweightMyPlaces,
            isLoadingTikToks: tikTokVM.isLoadingTikTokPlaces,
            isLoadingReviews: reviewsVM.isLoadingReviewedPlaces,
            isLoadingMyPlaces: myPlacesVM.isMyPlacesLoading
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
            onMyPlacesTap: handleMyPlacesTap,
            onTikTokHelpTap: { activePopupSheet = .help }
        )
        .sheet(item: $activePopupSheet, onDismiss: handlePopupDismiss) { sheet in
            popupContent(for: sheet)
        }
    }

    // MARK: - Popup Content

    /// Returns the appropriate popup view for the given sheet type.
    @ViewBuilder
    private func popupContent(for sheet: ProfilePopupSheet) -> some View {
        switch sheet {
        case .myPlaces:
            MyPlacesListView(
                myPlacesVM: myPlacesVM,
                onViewOnMap: { requestMapNavigation(.myPlaces) }
            )
        case .favorites:
            FavoritesPopupView(
                favoritesVM: favoritesVM,
                onViewOnMap: { requestMapNavigation(.favorites) }
            )
        case .tiktoks:
            TikToksPopupView(
                tikTokVM: tikTokVM,
                showNearbyFilter: false,
                onViewOnMap: { requestMapNavigation(.tiktoks) }
            )
        case .reviews:
            ReviewsListPopupView(
                reviewsVM: reviewsVM,
                onViewOnMap: { requestMapNavigation(.reviews) }
            )
        case .help:
            TikTokImportHelpView()
        }
    }

    // MARK: - Actions

    /// Handles tap on favorites section - shows popup over profile.
    private func handleFavoritesTap() {
        activePopupSheet = .favorites
    }

    /// Handles tap on TikToks section - shows popup over profile.
    private func handleTikToksTap() {
        activePopupSheet = .tiktoks
    }

    /// Handles tap on reviews section - shows popup over profile.
    private func handleReviewsTap() {
        activePopupSheet = .reviews
    }

    /// Handles tap on My Places section - shows popup over profile.
    private func handleMyPlacesTap() {
        activePopupSheet = .myPlaces
    }

    /// Sets pending map navigation and dismisses the popup sheet.
    private func requestMapNavigation(_ sheet: ProfilePopupSheet) {
        pendingMapNavigation = sheet
        activePopupSheet = nil
    }

    /// Called when popup sheet is dismissed - sets deferred map filter and dismisses profile.
    /// Uses pendingMapFilter (not showXOnMap) so the sheet is only presented after
    /// the profile fullScreenCover finishes dismissing via its onDismiss callback.
    private func handlePopupDismiss() {
        guard let pending = pendingMapNavigation else { return }
        pendingMapNavigation = nil

        switch pending {
        case .myPlaces:
            profile.pendingMapFilter = .myPlaces
        case .favorites:
            profile.pendingMapFilter = .favorites
        case .tiktoks:
            profile.pendingMapFilter = .tiktoks
        case .reviews:
            profile.pendingMapFilter = .reviews
        case .help:
            return
        }

        presentationMode.wrappedValue.dismiss()
    }
}
