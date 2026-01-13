//
//  FavoritesPopupView.swift
//  loc
//
//  Single Responsibility: Display favorite places in a popup grid
//  MVVM: Delegates data loading and state to ProfileViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI

struct FavoritesPopupView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        PlaceListPopupView(
            title: "Favorites",
            isLoading: false, // Favorites are loaded with profile
            isLoadingMore: false, // No pagination for favorites
            places: profile.favoritesAsLightweight,
            hasMore: false, // No pagination for favorites
            emptyIcon: "heart",
            emptyTitle: "No Favorites Yet",
            emptyMessage: "Add places to your favorites to see them here",
            loadMore: { }, // No pagination needed
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: false, // Favorites use review photos
                    allowDelete: false, // Handled elsewhere
                    onNavigate: navigate
                )
            }
        )
    }
}
