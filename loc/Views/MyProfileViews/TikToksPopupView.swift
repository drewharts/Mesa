//
//  TikToksPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated TikTok places in a popup grid
//  MVVM: Delegates data loading and state to ProfileTikTokViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI

struct TikToksPopupView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var tikTokVM: ProfileTikTokViewModel

    var body: some View {
        PlaceListPopupView(
            title: "TikToks",
            count: tikTokVM.totalExternalPlacesCount,
            isLoading: tikTokVM.isLoadingTikTokPlaces,
            isLoadingMore: tikTokVM.isLoadingMoreExternalPlaces,
            places: tikTokVM.lightweightExternalPlaces,
            hasMore: tikTokVM.hasMoreExternalPlaces,
            emptyIcon: "video",
            emptyTitle: "No TikToks Yet",
            emptyMessage: "Places you add from TikTok videos will appear here",
            loadMore: { await tikTokVM.loadMoreExternalPlaces() },
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: true,
                    onNavigate: navigate
                )
                .contextMenu {
                    Button(role: .destructive) {
                        profile.tikTokViewModel.deleteTikTokPlace(place)
                    } label: {
                        Label("Delete TikTok Place", systemImage: "trash")
                    }
                }
            }
        )
        .onAppear {
            // Only load if not already loaded (same pattern as list sheets)
            // This preserves scroll position on back navigation
            if tikTokVM.lightweightExternalPlaces.isEmpty {
                profile.tikTokViewModel.refreshTikTokPlacesAfterImport()
            }
        }
    }
}
