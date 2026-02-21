//
//  ReviewsListPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated reviewed places in a popup grid
//  MVVM: Delegates data loading and state to ProfileReviewsViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI

struct ReviewsListPopupView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var reviewsVM: ProfileReviewsViewModel
    var onViewOnMap: (() -> Void)? = nil

    var body: some View {
        PlaceListPopupView(
            title: "Reviews",
            count: reviewsVM.totalReviewedPlacesCount,
            isLoading: reviewsVM.isLoadingReviewedPlaces,
            isLoadingMore: reviewsVM.isLoadingMoreReviews,
            places: reviewsVM.lightweightReviewedPlaces,
            hasMore: reviewsVM.hasMoreReviews,
            emptyIcon: "star.bubble",
            emptyTitle: "No Reviews Yet",
            emptyMessage: "Places you've reviewed will appear here",
            loadMore: { await reviewsVM.loadMoreMyReviews() },
            onViewOnMap: onViewOnMap,
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferExternalThumbnail: false,
                    onNavigate: navigate
                )
            }
        )
    }
}
