//
//  PlaceReviewsView.swift
//  loc
//
//  Refactored to use proper MVVM with PlaceReviewsViewModel
//  Comments functionality removed for simplification
//

import SwiftUI

struct PlaceReviewsView: View {
    @ObservedObject var viewModel: PlaceReviewsViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    // Still needed for child views (temporary)
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 24) {
                    switch viewModel.loadingState {
                    case .loading:
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                        
                    case .loaded:
                        if viewModel.hasReviews {
                            PlaceReviewsListView(
                                viewModel: viewModel,
                                onPhotoTapped: onPhotoTapped,
                                scrollProxy: scrollProxy
                            )
                        } else {
                            Text(viewModel.emptyStateMessage)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(20)
                        }
                        
                    case .error(let error):
                        Text("Failed to load reviews: \(error.localizedDescription)")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding()
                        
                    case .idle:
                        Text("Reviews not yet loaded")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
            }
            .background(Color.white)
            .padding(.horizontal, -50)
            .ignoresSafeArea(.all, edges: .all)
            .onChange(of: viewModel.highlightedReviewId) { _, reviewId in
                if let reviewId = reviewId {
                    scrollToReview(reviewId, proxy: scrollProxy)
                }
            }
        }
        .onAppear {
            viewModel.checkLikeStatuses()
        }
    }
    
    private func scrollToReview(_ reviewId: String, proxy: ScrollViewProxy) {
        // Wait for reviews to load, then scroll
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                proxy.scrollTo(reviewId, anchor: .center)
            }
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Clear after scrolling
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                viewModel.clearHighlightedReview()
            }
        }
    }
}
