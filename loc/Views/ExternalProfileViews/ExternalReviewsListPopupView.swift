//
//  ExternalReviewsListPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated reviewed places for an external user in a popup grid
//  MVVM: Delegates data loading and state to MapDisplayCoordinatorViewModel
//  Now presented from MapContainerView with all environment objects available
//

import SwiftUI

struct ExternalReviewsListPopupView: View {
    @ObservedObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @ObservedObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        PlaceListPopupView(
            title: "\(mapDisplayCoordinatorVM.mapDisplayUserName ?? "User")'s Reviews",
            count: mapDisplayCoordinatorVM.mapDisplayReviewsCount,
            isLoading: false, // Data is already loaded when triggering map display
            isLoadingMore: false, // No pagination in map display mode
            places: mapDisplayCoordinatorVM.mapDisplayReviews,
            hasMore: false, // No pagination in map display mode
            emptyIcon: "star.bubble",
            emptyTitle: "No Reviews Yet",
            emptyMessage: "This user hasn't reviewed any places yet",
            loadMore: { }, // No pagination in map display mode
            onBackToProfile: {
                userProfileNavigationVM.isUserDetailPresented = true
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
