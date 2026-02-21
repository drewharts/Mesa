//
//  ExternalContentChangeHandler.swift
//  loc
//
//  ViewModifier that handles external video onChange events.
//  Extracted to reduce type-checking complexity in PlaceDetailView.
//

import SwiftUI

/// Handles onChange events for external video updates.
struct ExternalContentChangeHandler: ViewModifier {
    @Binding var tabsViewModel: PlaceDetailTabsViewModel?

    @ObservedObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var profile: ProfileViewModel
    @ObservedObject var externalContentVM: ProfileExternalContentViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedPlaceVM.externalVideos) { _, newVideos in
                handleExternalVideosChanged(newVideos)
            }
            .onChange(of: externalContentVM.userExternalPlaces.count) { _, _ in
                handleExternalPlacesChanged()
            }
    }

    // MARK: - Handler Methods

    /// Handles external videos changes from the place.
    private func handleExternalVideosChanged(_ newVideos: [ExternalVideo]) {
        guard let place = selectedPlaceVM.selectedPlace else { return }
        let userVideos = profile.externalContentViewModel.getExternalVideosSync(for: place.id.uuidString)
        tabsViewModel?.setExternalVideos(placeVideos: newVideos, userVideos: userVideos)
    }

    /// Handles external places changes (user's video associations).
    private func handleExternalPlacesChanged() {
        guard let place = selectedPlaceVM.selectedPlace else { return }
        let userVideos = profile.externalContentViewModel.getExternalVideosSync(for: place.id.uuidString)
        tabsViewModel?.setExternalVideos(placeVideos: selectedPlaceVM.externalVideos, userVideos: userVideos)
    }
}
