//
//  FavoritesChangeHandler.swift
//  loc
//
//  ViewModifier that handles favorites-related onChange events.
//  Extracted to reduce type-checking complexity in PlaceDetailView.
//

import SwiftUI

/// Handles onChange events for favorites updates.
struct FavoritesChangeHandler: ViewModifier {
    @Binding var tabsViewModel: PlaceDetailTabsViewModel?

    @ObservedObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var profile: ProfileViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: profile.showMaxFavoritesAlert) { _, showAlert in
                handleMaxFavoritesAlert(showAlert)
            }
            .onChange(of: profile.lightweightFavorites) { _, _ in
                handleFavoritesChanged()
            }
            .onChange(of: profile.userFavorites) { _, _ in
                handleFavoritesChanged()
            }
    }

    // MARK: - Handler Methods

    /// Handles max favorites alert from ProfileViewModel.
    private func handleMaxFavoritesAlert(_ showAlert: Bool) {
        guard showAlert else { return }
        tabsViewModel?.handleMaxFavoritesAlert()
        profile.showMaxFavoritesAlert = false
    }

    /// Handles favorites list changes.
    private func handleFavoritesChanged() {
        guard let place = selectedPlaceVM.selectedPlace else { return }
        let isFavorited = profile.isPlaceFavorite(placeId: place.id.uuidString)
        tabsViewModel?.setFavoriteStatus(isFavorited)
    }
}
