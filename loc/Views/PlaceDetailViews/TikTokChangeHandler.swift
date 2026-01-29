//
//  TikTokChangeHandler.swift
//  loc
//
//  ViewModifier that handles TikTok video onChange events.
//  Extracted to reduce type-checking complexity in PlaceDetailView.
//

import SwiftUI

/// Handles onChange events for TikTok video updates.
struct TikTokChangeHandler: ViewModifier {
    @Binding var tabsViewModel: PlaceDetailTabsViewModel?

    @ObservedObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var profile: ProfileViewModel

    /// Convenience accessor for TikTok view model.
    private var tikTokVM: ProfileTikTokViewModel { profile.tikTokViewModel }

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedPlaceVM.tiktokVideos) { _, newVideos in
                handleTikTokVideosChanged(newVideos)
            }
            .onChange(of: tikTokVM.userExternalPlaces.count) { _, _ in
                handleExternalPlacesChanged()
            }
    }

    // MARK: - Handler Methods

    /// Handles TikTok videos changes from the place.
    private func handleTikTokVideosChanged(_ newVideos: [TikTokVideo]) {
        guard let place = selectedPlaceVM.selectedPlace else { return }
        let userVideos = profile.getTikTokVideosSync(for: place.id.uuidString)
        tabsViewModel?.setTikTokVideos(placeVideos: newVideos, userVideos: userVideos)
    }

    /// Handles external places changes (user's TikTok associations).
    private func handleExternalPlacesChanged() {
        guard let place = selectedPlaceVM.selectedPlace else { return }
        let userVideos = profile.getTikTokVideosSync(for: place.id.uuidString)
        tabsViewModel?.setTikTokVideos(placeVideos: selectedPlaceVM.tiktokVideos, userVideos: userVideos)
    }
}
