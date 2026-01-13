//
//  ExternalFavoritesListPopupView.swift
//  loc
//
//  Single Responsibility: Display favorite places for an external user in a popup grid
//  MVVM: Delegates data loading and state to UserProfileViewModel
//  Presented from MapContainerView with all environment objects available
//

import SwiftUI

struct ExternalFavoritesListPopupView: View {
    @ObservedObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        PlaceListPopupView(
            title: "\(userProfileVM.selectedUser?.firstName ?? "User")'s Favorites",
            isLoading: false, // Favorites are loaded with profile, no separate loading
            isLoadingMore: false, // No pagination for favorites
            places: userProfileVM.lightweightFavorites,
            hasMore: false, // No pagination for favorites
            emptyIcon: "heart",
            emptyTitle: "No Favorites Yet",
            emptyMessage: "This user hasn't added any favorite places yet",
            loadMore: { }, // No pagination needed
            onBackToProfile: {
                userProfileVM.isUserDetailPresented = true
            },
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: false, // Favorites use review photos
                    allowDelete: false, // Can't delete other user's favorites
                    onNavigate: navigate
                )
            }
        )
    }
}
