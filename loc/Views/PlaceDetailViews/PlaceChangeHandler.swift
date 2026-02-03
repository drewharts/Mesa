//
//  PlaceChangeHandler.swift
//  loc
//
//  ViewModifier that handles place selection changes.
//  Posts sync is now handled by PlacePostsCacheService subscription in PlaceDetailTabsViewModel.
//

import SwiftUI

/// Handles onChange events for place selection.
struct PlaceChangeHandler: ViewModifier {
    @Binding var tabsViewModel: PlaceDetailTabsViewModel?

    @ObservedObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var profile: ProfileViewModel
    @ObservedObject var locationManager: LocationManager

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedPlaceVM.selectedPlace) { _, newPlace in
                handlePlaceChanged(newPlace)
            }
    }

    // MARK: - Handler Methods

    /// Handles place selection changes by updating all dependent state.
    private func handlePlaceChanged(_ newPlace: DetailPlace?) {
        tabsViewModel?.setPlace(newPlace)

        guard let place = newPlace else { return }

        updateTravelTime(for: place)
        updateFavoriteStatus(for: place)
        updateUserTikTokVideos(for: place)

        // Set rating from metadata (posts handled by PlacePostsCacheService subscription)
        tabsViewModel?.setRating(selectedPlaceVM.placeRating)
    }

    /// Updates travel time for the given place.
    private func updateTravelTime(for place: DetailPlace) {
        guard let currentLocation = locationManager.currentLocation?.coordinate else { return }
        tabsViewModel?.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation)
    }

    /// Updates favorite status for the given place.
    private func updateFavoriteStatus(for place: DetailPlace) {
        let isFavorited = profile.isPlaceFavorite(placeId: place.id.uuidString)
        tabsViewModel?.setFavoriteStatus(isFavorited)
    }

    /// Updates user TikTok videos for the given place (place TikToks handled by PlacePostsCacheService).
    private func updateUserTikTokVideos(for place: DetailPlace) {
        let userVideos = profile.getTikTokVideosSync(for: place.id.uuidString)
        tabsViewModel?.aboutTabViewModel.tikTokVideosViewModel.setUserVideos(userVideos)
    }
}
