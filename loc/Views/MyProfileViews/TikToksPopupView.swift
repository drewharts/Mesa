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
            cardBuilder: { place in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: true,
                    allowDelete: true,
                    deleteTitle: "Delete TikTok Place",
                    onDelete: { profile.deleteTikTokPlace(place) }
                )
            }
        )
        .onAppear {
            if profile.lightweightExternalPlaces.isEmpty {
                Task { await profile.loadInitialExternalPlaces() }
            }
        }
    }
}
