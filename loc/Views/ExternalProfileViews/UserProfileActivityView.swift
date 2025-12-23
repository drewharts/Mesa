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
    @Environment(\.presentationMode) var presentationMode
    
    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // MARK: - Computed Properties
    
    private var hasMoreReviews: Bool {
        guard let userId = UserProfileVM.selectedUser?.id else { return false }
        return UserProfileVM.hasMoreReviews(for: userId)
    }
    
    private var reviewedPlaces: [LightweightPlace] {
        UserProfileVM.getReviewedPlaces()
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            content
            Spacer(minLength: 50)
        }
        .padding(.bottom, 20)
        .onAppear {
            UserProfileVM.loadUserReviewedPlacesWithPagination()
        }
        .onChange(of: UserProfileVM.selectedUser?.id) {
            UserProfileVM.resetReviewedPlacesLoadingState()
            UserProfileVM.loadUserReviewedPlacesWithPagination()
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if UserProfileVM.isLoadingReviewedPlaces {
            initialLoadingView
        } else if !reviewedPlaces.isEmpty {
            gridView
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Initial Loading View
    
    private var initialLoadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Reviews Yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("This user hasn't reviewed any places yet")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(reviewedPlaces.enumerated()), id: \.element.id) { index, place in
                    // Use LightweightPlaceGridCell for consistent image loading
                    // Uses latest_review_photo which includes external review photos
                    LightweightPlaceGridCell(place: place)
                        .onAppear {
                            handlePlaceAppear(index: index)
                        }
                }
                
                // Pagination loading indicator
                if UserProfileVM.isLoadingMoreReviews {
                    paginationLoadingView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Pagination Loading View
    
    private var paginationLoadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
        .gridCellColumns(2)
    }
    
    // MARK: - Actions
    
    private func handlePlaceAppear(index: Int) {
        // Trigger pagination when within 3 items of the end (smoother infinite scroll)
        let threshold = max(0, reviewedPlaces.count - 3)
        guard index >= threshold,
              hasMoreReviews,
              !UserProfileVM.isLoadingMoreReviews else { return }
        
        UserProfileVM.loadMoreReviews()
    }
}
