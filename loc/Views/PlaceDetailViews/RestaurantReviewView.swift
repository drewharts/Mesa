//
//  RestaurantReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/1/25.
//  Refactored - comments removed for simplification
//

import SwiftUI
import UIKit

struct RestaurantReviewView: View {
    let review: RestaurantReview
    @ObservedObject var viewModel: PlaceReviewsViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    
    // Computed properties to help the compiler
    private var reviewPhotos: [UIImage] {
        viewModel.getPhotos(for: review)
    }
    
    private var loadingState: PlacePhotosViewModel.LoadingState {
        viewModel.getPhotoLoadingState(for: review)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header: Profile Picture, Name, and Timestamp
            RestaruantReviewViewProfileInformation(
                review: review,
                photosViewModel: viewModel.photosViewModel
            )

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
            photoSection
        }
        .padding(.vertical)
    }
    
    @ViewBuilder
    private var photoSection: some View {
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
                                            if let originalReview = viewModel.getReview(by: review.id) {
                                                viewModel.loadMorePhotos(for: review.id, allImageUrls: originalReview.images)
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
                        viewModel.reloadPhotos(for: review)
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
    }
}

