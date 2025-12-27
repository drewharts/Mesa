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
    
    var body: some View {
        PlaceListPopupView(
            title: "Reviews",
            count: userProfileVM.totalReviewedPlacesCount,
            isLoading: userProfileVM.isLoadingReviewedPlaces,
            isLoadingMore: userProfileVM.isLoadingMoreReviews,
            places: userProfileVM.lightweightReviewedPlaces,
            hasMore: userProfileVM.hasMoreReviews,
            emptyIcon: "star.bubble",
            emptyTitle: "No Reviews Yet",
            emptyMessage: "This user hasn't reviewed any places yet",
            loadMore: { await userProfileVM.loadMoreReviews() },
            cardBuilder: { place in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: false, // Reviews prioritize review photos
                    allowDelete: false, // Can't delete other user's reviews
                    onNavigate: { placeId in
                        navigateToPlace(placeId: placeId)
                    }
                )
            }
        )
        .onAppear {
            if userProfileVM.lightweightReviewedPlaces.isEmpty {
                Task {
                    await userProfileVM.loadUserReviewedPlacesWithPagination()
                }
            }
        }
    }
    
    /// Navigate to place from external profile - dismisses entire profile sheet first
    private func navigateToPlace(placeId: String) {
        Task {
            guard let detailPlace = try? await PlaceService.shared.fetchPlace(withId: placeId) else { return }
            await MainActor.run {
                userProfileVM.navigateToPlaceFromProfile(detailPlace, selectedPlaceVM: selectedPlaceVM)
            }
        }
    }
}

