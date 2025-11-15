//
//  GenericReviewView.swift
//  loc
//
//  Refactored - comments removed for simplification
//

import SwiftUI

struct GenericReviewView: View {
    let review: GenericReview
    @ObservedObject var viewModel: PlaceReviewsViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        VStack(spacing: 16) {
            // Header: Profile Picture, Name, and Timestamp
            RestaruantReviewViewProfileInformation(review: review)
            
            // Review Text
            Text(review.reviewText)
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 15)
            
            // Images (Horizontal Scrolling) with Loading State
            let reviewPhotos = viewModel.getPhotos(for: review)
            let loadingState = viewModel.getPhotoLoadingState(for: review)
            
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
            
            // Comments section removed for simplification
        }
        .padding(.vertical)
    }
}
