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
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("PLACES REVIEWED")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .foregroundStyle(.black)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                if UserProfileVM.isLoadingReviewedPlaces {
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
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(UserProfileVM.getReviewedPlaces(), id: \.id) { place in
                            UserReviewedPlaceGridCell(
                                place: place,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                        }
                    }
                    .padding(.horizontal, 20)
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
            UserProfileVM.loadUserReviewedPlacesIfNeeded()
        }
        .onChange(of: UserProfileVM.selectedUser?.id) {
            // Reset loading state when user changes and load new data
            UserProfileVM.resetReviewedPlacesLoadingState()
            UserProfileVM.loadUserReviewedPlacesIfNeeded()
        }
        .onChange(of: detailPlaceViewModel.placeSavers) {
            // Stop loading when new data comes in
            if UserProfileVM.isLoadingReviewedPlaces {
                UserProfileVM.isLoadingReviewedPlaces = false
            }
        }
    }
} 