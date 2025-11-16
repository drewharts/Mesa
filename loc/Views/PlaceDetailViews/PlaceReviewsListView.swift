//
//  PlaceReviewsListView.swift
//  loc
//
//  Refactored to use ViewModel, comments removed for simplification
//

import SwiftUI
import UIKit

struct PlaceReviewsListView : View {
    @ObservedObject var viewModel: PlaceReviewsViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    let scrollProxy: ScrollViewProxy
    
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    
    @State private var reviewToDelete: (any ReviewProtocol)? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        ForEach(viewModel.reviews, id: \.id) { review in
            Group {
                if let restaurantReview = review as? RestaurantReview {
                    RestaurantReviewView(
                        review: restaurantReview,
                        viewModel: viewModel,
                        onPhotoTapped: onPhotoTapped
                    )
                        .id(review.id)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    .background(viewModel.highlightedReviewId == review.id ? 
                                   Color.blue.opacity(0.1) : Color.white)
                        .cornerRadius(10)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.highlightedReviewId)
                } else if let genericReview = review as? GenericReview {
                    GenericReviewView(
                        review: genericReview,
                        viewModel: viewModel,
                        onPhotoTapped: onPhotoTapped
                    )
                        .environmentObject(userProfileViewModel)
                        .id(review.id)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    .background(viewModel.highlightedReviewId == review.id ? 
                                   Color.blue.opacity(0.1) : Color.white)
                        .cornerRadius(10)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.highlightedReviewId)
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                // Only allow deletion if this is the user's own review
                if review.userId == userSession.currentUserId {
                    // Haptic feedback
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    
                    reviewToDelete = review
                    showDeleteConfirmation = true
                }
            }
        }
        .alert("Delete Review", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                reviewToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let review = reviewToDelete {
                    deleteReview(review)
                }
            }
        } message: {
            Text("Are you sure you want to delete this review? This action cannot be undone.")
        }
    }
    
    private func deleteReview(_ review: any ReviewProtocol) {
        selectedPlaceVM.deleteReview(reviewId: review.id) { result in
            switch result {
            case .success:
                print("✅ Review deleted successfully")
                // The view model should handle updating the reviews list
            case .failure(let error):
                print("❌ Failed to delete review: \(error.localizedDescription)")
                // You might want to show an error alert here
            }
        }
        reviewToDelete = nil
    }
    
    private func scrollToReview(_ reviewId: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                proxy.scrollTo(reviewId, anchor: .top)
            }
        }
    }
}