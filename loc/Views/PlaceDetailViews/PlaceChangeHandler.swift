//
//  PlaceChangeHandler.swift
//  loc
//
//  ViewModifier that handles place selection changes.
//  Distinguishes between a new place selection and a data refresh of the same place.
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
            .onChange(of: selectedPlaceVM.selectedPlace) { oldPlace, newPlace in
                if isSamePlaceRefresh(old: oldPlace, new: newPlace) {
                    tabsViewModel?.refreshPlaceData(newPlace)
                    // Recalculate travel time if the refresh brought real coordinates
                    if let place = newPlace, place.coordinate != nil,
                       tabsViewModel?.travelTimeViewModel.travelTimes.isEmpty == true {
                        updateTravelTime(for: place)
                    }
                } else {
                    handleNewPlaceSelected(newPlace)
                }
            }
    }

    // MARK: - Handler Methods

    /// Returns true when the same place is being updated with fresh data (not a new selection).
    private func isSamePlaceRefresh(old: DetailPlace?, new: DetailPlace?) -> Bool {
        guard let old = old, let new = new else { return false }
        // Same row, or the same real Google place under a new id. Two different rows that both lack
        // a Google id ("" == "") used to count as the same place, which kept the old place's content.
        return PlaceSelectionIdentity.isSamePlace(
            oldId: old.id.uuidString,
            oldGooglePlaceId: old.googlePlaceId,
            newId: new.id.uuidString,
            newGooglePlaceId: new.googlePlaceId
        )
    }

    /// Handles a genuinely new place selection by resetting all dependent state.
    private func handleNewPlaceSelected(_ newPlace: DetailPlace?) {
        tabsViewModel?.setPlace(newPlace)

        guard let place = newPlace else { return }

        updateTravelTime(for: place)
        updateUserExternalVideos(for: place)

        // Set rating from metadata (posts handled by PlacePostsCacheService subscription)
        tabsViewModel?.setRating(selectedPlaceVM.placeRating)
    }

    /// Updates travel time for the given place.
    private func updateTravelTime(for place: DetailPlace) {
        guard let currentLocation = locationManager.currentLocation?.coordinate else { return }
        tabsViewModel?.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation)
    }



    /// Updates user external videos for the given place (place videos handled by PlacePostsCacheService).
    private func updateUserExternalVideos(for place: DetailPlace) {
        let userVideos = profile.externalContentViewModel.getExternalVideosSync(for: place.id.uuidString)
        tabsViewModel?.aboutTabViewModel.externalVideosViewModel.setUserVideos(userVideos)
    }
}
