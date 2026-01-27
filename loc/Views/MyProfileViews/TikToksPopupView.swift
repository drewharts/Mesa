//
//  TikToksPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated TikTok places in a popup grid
//  MVVM: Delegates data loading and state to ProfileViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI

struct TikToksPopupView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var mapViewModel: MapViewModel

    var body: some View {
        PlaceListPopupView(
            title: "TikToks",
            count: profile.totalExternalPlacesCount,
            isLoading: profile.isLoadingTikTokPlaces,
            isLoadingMore: profile.isLoadingMoreExternalPlaces,
            places: profile.lightweightExternalPlaces,
            hasMore: profile.hasMoreExternalPlaces,
            emptyIcon: "video",
            emptyTitle: "No TikToks Yet",
            emptyMessage: "Places you add from TikTok videos will appear here",
            loadMore: { await profile.loadMoreExternalPlaces() },
            pendingPlaceNavigation: $mapViewModel.pendingPlaceNavigation,
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: true,
                    allowDelete: true,
                    deleteTitle: "Delete TikTok Place",
                    onDelete: { profile.deleteTikTokPlace(place) },
                    onNavigate: navigate
                )
            }
        )
        .onAppear {
            // Only load if not already loaded (same pattern as list sheets)
            // This preserves scroll position on back navigation
            if profile.lightweightExternalPlaces.isEmpty {
                profile.refreshTikTokPlacesAfterImport()
            }
        }
    }
}
