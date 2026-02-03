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

    /// Convenience accessor for reviews view model.
    private var reviewsVM: ProfileReviewsViewModel { profile.reviewsViewModel }

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
