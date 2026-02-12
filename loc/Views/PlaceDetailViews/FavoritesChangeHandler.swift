//
//  FavoritesChangeHandler.swift
//  loc
//
//  ViewModifier that handles favorites-related onChange events.
//  Extracted to reduce type-checking complexity in PlaceDetailView.
//

import SwiftUI

/// Handles onChange events for favorites updates — refreshes bookmark icon.
struct FavoritesChangeHandler: ViewModifier {
    @Binding var tabsViewModel: PlaceDetailTabsViewModel?
    @ObservedObject var favoritesVM: ProfileFavoritesViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: favoritesVM.lightweightFavorites) { _, _ in
                handleFavoritesChanged()
            }
            .onChange(of: favoritesVM.userFavorites) { _, _ in
                handleFavoritesChanged()
            }
    }

    // MARK: - Handler Methods

    /// Refreshes bookmark icon when favorites change.
    private func handleFavoritesChanged() {
        tabsViewModel?.refreshPlaceListMembership()
    }
}
