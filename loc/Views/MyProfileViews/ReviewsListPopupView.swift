//
//  ReviewsListPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated reviewed places in a popup grid
//  MVVM: Delegates data loading and state to ProfileViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI

struct ReviewsListPopupView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var mapViewModel: MapViewModel

    var body: some View {
        PlaceListPopupView(
            title: "Reviews",
            count: profile.totalReviewedPlacesCount,
            isLoading: profile.isLoadingReviewedPlaces,
            isLoadingMore: profile.isLoadingMoreReviews,
            places: profile.lightweightReviewedPlaces,
            hasMore: profile.hasMoreReviews,
            emptyIcon: "star.bubble",
            emptyTitle: "No Reviews Yet",
            emptyMessage: "Places you've reviewed will appear here",
            loadMore: { await profile.loadMoreMyReviews() },
            pendingPlaceNavigation: $mapViewModel.pendingPlaceNavigation,
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: false,  // Reviews prioritize review photos
                    allowDelete: false,
                    onNavigate: navigate
                )
            }
        )
        // ✅ MVVM + SRP: ViewModel automatically loads data when user is set
        // No manual loading needed - reactive observer handles it
    }
}
