//
//  PlacePhotosView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/10/25.
//

import SwiftUI
import CoreLocation

struct PlacePhotosView: View {
    @ObservedObject var viewModel: PlacePhotosViewModel

    let onPhotoTapped: ([String], Int) -> Void

    @State private var fullscreenVideoURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.place != nil {
                        switch viewModel.photoLoadingState {
                        case .idle, .loading:
                            photoGalleryContent

                        case .loaded:
                            photoGalleryContent

                        case .error(let error):
                            Text("Failed to load photos: \(error.localizedDescription)")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("No Place Selected")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            viewModel.loadInitialExternalReviewPhotos()
        }
        .fullScreenCover(item: $fullscreenVideoURL) { url in
            FullscreenVideoPlayerView(url: url)
        }
    }

    // MARK: - Photo Gallery Content

    @ViewBuilder
    private var photoGalleryContent: some View {
        let allItems = viewModel.combinedPhotoItems
        let displayItems = Array(allItems.prefix(10))
        let overflowCount = max(0, allItems.count - 10)

        if !displayItems.isEmpty {
            ModernPhotoGallery(
                items: displayItems,
                onImageTapped: { index in
                    let allURLs = viewModel.combinedPhotoURLs
                    onPhotoTapped(allURLs, index)
                },
                onVideoTapped: { videoUrlString in
                    fullscreenVideoURL = URL(string: videoUrlString)
                },
                overflowCount: overflowCount,
                onDeletePhoto: { item in
                    Task {
                        await viewModel.deleteExternalReviewPhoto(url: item.url)
                    }
                },
                photosViewModel: viewModel
            )
        } else if viewModel.isAnyPhotosLoading {
            photoShimmerPlaceholder
        } else {
            emptyStateView
        }
    }

    // MARK: - Shimmer Placeholder

    /// Shimmer placeholder matching the ModernPhotoGallery layout (hero + double row).
    private var photoShimmerPlaceholder: some View {
        VStack(spacing: 8) {
            ShimmerView()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                ShimmerView()
                    .aspectRatio(5/4, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                ShimmerView()
                    .aspectRatio(5/4, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No photos yet")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview
#Preview {
    let photosViewModel = PlacePhotosViewModel()

    // Create a mock place with all properties
    let mockPlace: DetailPlace = {
        var place = DetailPlace()
        place.name = "Sample Restaurant"
        place.address = "123 Main St"
        place.coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        return place
    }()

    // Set place data on refactored ViewModel
    photosViewModel.setPlace(mockPlace)

    return PlacePhotosView(
        viewModel: photosViewModel,
        onPhotoTapped: { urls, index in
            print("Tapped photo at index: \(index)")
        }
    )
    .padding()
}
