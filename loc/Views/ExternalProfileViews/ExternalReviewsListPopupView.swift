//
//  ExternalReviewsListPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated reviewed places for an external user in a popup grid
//  MVVM: Delegates data loading and state to UserProfileViewModel
//  Now presented from MapContainerView with all environment objects available
//

import SwiftUI

struct ExternalReviewsListPopupView: View {
    @ObservedObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        PlaceListPopupView(
            title: "\(userProfileVM.mapDisplayUserName ?? "User")'s Reviews",
            count: userProfileVM.mapDisplayReviewsCount,
            isLoading: false, // Data is already loaded when triggering map display
            isLoadingMore: false, // No pagination in map display mode
            places: userProfileVM.mapDisplayReviews,
            hasMore: false, // No pagination in map display mode
            emptyIcon: "star.bubble",
            emptyTitle: "No Reviews Yet",
            emptyMessage: "This user hasn't reviewed any places yet",
            loadMore: { }, // No pagination in map display mode
            onBackToProfile: {
                userProfileVM.isUserDetailPresented = true
            },
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: false, // Reviews prioritize review photos
                    allowDelete: false, // Can't delete other user's reviews
                    onNavigate: navigate
                )
            }
        )
    }
}
