//
//  PlaceChangeHandler.swift
//  loc
//
//  ViewModifier that handles place selection and posts update changes.
//  Extracted to reduce type-checking complexity in PlaceDetailView.
//

import SwiftUI

/// Handles onChange events for place selection and posts updates.
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
            .onChange(of: selectedPlaceVM.postsUpdateCounter) { _, _ in
                handlePostsUpdated()
            }
    }

    // MARK: - Handler Methods

    /// Handles place selection changes by updating all dependent state.
    private func handlePlaceChanged(_ newPlace: DetailPlace?) {
        tabsViewModel?.setPlace(newPlace)

        guard let place = newPlace else { return }

        updateTravelTime(for: place)
        updateFavoriteStatus(for: place)
        updateTikTokVideos(for: place)
        updatePostLoadingState(for: place)
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

    /// Updates TikTok videos for the given place.
    private func updateTikTokVideos(for place: DetailPlace) {
        let userVideos = profile.getTikTokVideosSync(for: place.id.uuidString)
        tabsViewModel?.setTikTokVideos(placeVideos: selectedPlaceVM.tiktokVideos, userVideos: userVideos)
    }

    /// Updates post loading state for the given place.
    private func updatePostLoadingState(for place: DetailPlace) {
        let loadingState = selectedPlaceVM.postLoadingState(forPlaceId: place.id.uuidString)
        tabsViewModel?.setPostLoadingState(mapLoadingState(loadingState))
    }

    /// Handles posts data updates and also refreshes TikToks and loading state since they load together.
    private func handlePostsUpdated() {
        tabsViewModel?.setPosts(selectedPlaceVM.posts, rating: selectedPlaceVM.placeRating)

        // Also update TikToks since they're loaded alongside posts
        guard let place = selectedPlaceVM.selectedPlace else { return }
        let userVideos = profile.getTikTokVideosSync(for: place.id.uuidString)
        print("🎬 [PlaceChangeHandler] handlePostsUpdated - placeVideos: \(selectedPlaceVM.tiktokVideos.count), userVideos: \(userVideos.count)")
        tabsViewModel?.setTikTokVideos(placeVideos: selectedPlaceVM.tiktokVideos, userVideos: userVideos)

        // Update loading state when posts finish loading
        updatePostLoadingState(for: place)
    }

    /// Maps PlacePostsCacheViewModel loading state to PlacePostsViewModel loading state.
    private func mapLoadingState(_ state: PlacePostsCacheViewModel.LoadingState) -> PlacePostsViewModel.LoadingState {
        switch state {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded:
            return .loaded
        case .error(let error):
            return .error(error)
        }
    }
}
