//
//  CityAllPhotosView.swift
//  loc
//
//  Vertical grid view showing all review photos for a city with pagination.
//

import SwiftUI

/// Full-screen vertical grid of all city review photos, navigated from "See All" in city detail.
struct CityAllPhotosView: View {
    @ObservedObject var viewModel: CityDetailViewModel
    let onPhotoTap: (CityReviewPhoto) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.reviewPhotos) { photo in
                    CityReviewPhotoTile(photo: photo, onTap: { onPhotoTap(photo) })
                        .frame(maxWidth: .infinity)
                        .onAppear { viewModel.loadMorePhotosIfNeeded(currentPhoto: photo) }
                }
            }
            .padding(.horizontal, 16)

            if viewModel.isLoadingMorePhotos {
                ProgressView()
                    .padding(.vertical, 16)
            }
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
    }
}
