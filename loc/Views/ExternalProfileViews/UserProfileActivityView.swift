//
//  UserProfileActivityView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileActivityView: View {
    @ObservedObject var UserProfileVM: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Same grid configuration as ListPlacesPopUpListView
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Computed property to get hasMoreReviews for current user
    private var hasMoreReviews: Bool {
        guard let userId = UserProfileVM.selectedUser?.id else { return false }
        return UserProfileVM.hasMoreReviews(for: userId)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                if UserProfileVM.isLoadingReviewedPlaces || (UserProfileVM.getReviewedPlaces().isEmpty && !UserProfileVM.isLoadingReviewedPlaces) {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading reviews...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else if !UserProfileVM.getReviewedPlaces().isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(Array(UserProfileVM.getReviewedPlaces().enumerated()), id: \.element.id) { index, place in
                                    UserReviewedPlaceGridCell(
                                        place: place,
                                        cardWidth: cardWidth,
                                        cardHeight: cardHeight
                                    )
                                    .onAppear {
                                        // Load more reviews when user reaches the very last item
                                        let lastIndex = UserProfileVM.getReviewedPlaces().count - 1
                                        if index == lastIndex && hasMoreReviews && !UserProfileVM.isLoadingMoreReviews {
                                            UserProfileVM.loadMoreReviews()
                                        }
                                    }
                                }
                                
                                // Loading indicator for pagination
                                if UserProfileVM.isLoadingMoreReviews {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading more...")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .gridCellColumns(2)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                } else {
                    Text("No places reviewed yet")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20)
                        .padding(.vertical, 30)
                }
            }
            
            Spacer(minLength: 50)
        }
        .padding(.bottom, 20)
        .onAppear {
            UserProfileVM.loadUserReviewedPlacesWithPagination()
        }
        .onChange(of: UserProfileVM.selectedUser?.id) {
            // Reset loading state when user changes and load new data
            UserProfileVM.resetReviewedPlacesLoadingState()
            UserProfileVM.loadUserReviewedPlacesWithPagination()
        }
        .onChange(of: detailPlaceViewModel.placeSavers) {
            // Stop loading when new data comes in
            if UserProfileVM.isLoadingReviewedPlaces {
                UserProfileVM.isLoadingReviewedPlaces = false
            }
        }
    }
} 