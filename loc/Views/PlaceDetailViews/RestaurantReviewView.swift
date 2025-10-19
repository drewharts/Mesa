//
//  PlaceReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/1/25.
//

import SwiftUI
import UIKit

struct RestaurantReviewView: View {
    let review: RestaurantReview
    let onPhotoTapped: ([UIImage], Int) -> Void
    @Binding var isActiveKeyboard: Bool
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @State private var showComments = false
    
    // Static dictionary to track which review comments should be hidden
    private static var hiddenComments = [String: Bool]()
    
    // Static method to hide comments for a specific review
    static func hideComments(reviewId: String) {
        // This is called from InlineCommentsView to hide its parent review's comments
        Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("HideCommentsFor-\(reviewId)"), object: nil)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header: Profile Picture, Name, and Timestamp
            RestaruantReviewViewProfileInformation(review: review)

            // Ratings (Food, Ambience, Service)
            HStack(spacing: 45) {
                RatingView(title: "Food", score: review.foodRating, color: .green)
                RatingView(title: "Ambience", score: review.ambienceRating, color: .green)
                RatingView(title: "Service", score: review.serviceRating, color: .yellow)
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
            
            // Must Order Section
            RestaruantReviewViewMustOrder(review: review)
            
            // Review Text
            Text(review.reviewText)
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 15)
            
            // Images (Horizontal Scrolling) with Loading State
            let reviewPhotos = selectedPlaceVM.photos(for: review)
            let loadingState = selectedPlaceVM.photoLoadingState(for: review)
            
            switch loadingState {
            case .loading:
                ZStack {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading photos...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                }
                .frame(height: 150)
                .padding(.horizontal)
                
            case .loaded:
                if !reviewPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(Array(reviewPhotos.enumerated()), id: \.offset) { index, photo in
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .shadow(radius: 2)
                                    .onTapGesture {
                                        onPhotoTapped(reviewPhotos, index)
                                    }
                                    .onAppear {
                                        // Load more photos when user scrolls to the last visible photo
                                        if index == reviewPhotos.count - 1 {
                                            // Get the original review to access all image URLs
                                            if let originalReview = selectedPlaceVM.getReview(by: review.id) {
                                                selectedPlaceVM.loadMoreReviewPhotos(for: review.id, allImageUrls: originalReview.images)
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("No photos available")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                
            case .error(let error):
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        
                        Text("Failed to load photos: \(error.localizedDescription)")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Trigger reload of photos
                        selectedPlaceVM.reloadReviewPhotos(for: review)
                    }) {
                        Text("Retry")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                
            case .idle:
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            
            if showComments {
                // Show comments section when expanded
                VStack(alignment: .leading, spacing: 10) {
                    // Embedded comments view
                    InlineCommentsView(reviewId: review.id, onPhotoTapped: onPhotoTapped, onKeyboardActive: { isActive in
                        isActiveKeyboard = isActive
                    })
                        .padding(.leading, 15) // Indentation for comments
                }
                .padding(8)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Show reply button when comments are hidden
                HStack(spacing: 8) {
                    // Small horizontal line
                    Rectangle()
                        .frame(width: 16, height: 1)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    // Comment button positioned to the left
                    Button(action: {
                        // ✅ Optimize comment loading to prevent UI blocking
                        if !showComments {
                            // Only fetch comments if we don't already have them
                            if selectedPlaceVM.commentLoadingState(for: review.id) == .idle {
                                // Load comments in background to prevent UI blocking
                                Task.detached(priority: .background) {
                                    await selectedPlaceVM.loadCommentsForReview(reviewId: review.id)
                                }
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showComments.toggle()
                            }
                        }
                    }) {
                        let commentCount = selectedPlaceVM.commentCount(for: review.id)
                        Text(commentCount > 0 ? 
                             "Show \(commentCount) \(commentCount == 1 ? "reply" : "replies")" : 
                             "Reply")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding(.leading, 30) // Left padding to align with the indentation
                .padding(.bottom, 10)
            }
        }
        .padding(.vertical)
        .onAppear {
            // Check like statuses using the proper userId from profile
            if let currentUserId = userSession.currentUserId {
                selectedPlaceVM.checkLikeStatuses(userId: currentUserId)
            }
            
            // Listen for the hide comments notification
            NotificationCenter.default.addObserver(forName: Foundation.Notification.Name("HideCommentsFor-\(review.id)"), object: nil, queue: .main) { _ in
                withAnimation {
                    showComments = false
                }
            }
        }
        .onDisappear {
            // Remove the observer when view disappears
            NotificationCenter.default.removeObserver(self, name: Foundation.Notification.Name("HideCommentsFor-\(review.id)"), object: nil)
        }
    }
}

