//
//  ExternalReviewsListPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated reviewed places for an external user in a popup grid
//  MVVM: Delegates data loading and state to UserProfileViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior
//

import SwiftUI

struct ExternalReviewsListPopupView: View {
    @ObservedObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    private var userId: String {
        userProfileVM.selectedUser?.id ?? ""
    }
    
    private var hasMore: Bool {
        userProfileVM.hasMoreReviews(for: userId)
    }
    
    var body: some View {
        PlaceListPopupView(
            title: "Reviews",
            count: userProfileVM.lightweightReviewedPlaces.count,
            isLoading: userProfileVM.isLoadingReviewedPlaces,
            isLoadingMore: userProfileVM.isLoadingMoreReviews,
            places: userProfileVM.lightweightReviewedPlaces,
            hasMore: hasMore,
            emptyIcon: "star.bubble",
            emptyTitle: "No Reviews Yet",
            emptyMessage: "This user hasn't reviewed any places yet",
            loadMore: { userProfileVM.loadMoreReviews() },
            cardBuilder: { place in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: false, // Reviews prioritize review photos
                    allowDelete: false // Can't delete other user's reviews
                )
            }
        )
        .onAppear {
            if userProfileVM.lightweightReviewedPlaces.isEmpty {
                userProfileVM.loadUserReviewedPlacesWithPagination()
            }
        }
    }
}

