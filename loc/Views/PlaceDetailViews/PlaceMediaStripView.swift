//
//  PlaceMediaStripView.swift
//  loc
//
//  Horizontal strip of place photos and videos shown near the top of place detail.
//  Tiles that fail to load are hidden; the whole strip collapses when there is nothing to show.
//

import SwiftUI

struct PlaceMediaStripView: View {
    @ObservedObject var viewModel: PlaceMediaStripViewModel
    @EnvironmentObject var userSession: UserSession

    let placeId: String
    /// Opens the fullscreen photo gallery with every photo URL and the tapped index.
    let onPhotoTapped: ([String], Int) -> Void

    @State private var fullscreenVideoURL: URL?
    @State private var photoToDelete: PlaceMediaStripItem?

    private let tileHeight: CGFloat = 112
    private let photoWidth: CGFloat = 116
    private let videoWidth: CGFloat = 84
    private let tileSpacing: CGFloat = 6
    private let cornerRadius: CGFloat = 10

    var body: some View {
        let content = viewModel.content
        Group {
            if !content.items.isEmpty {
                strip(content)
            } else if viewModel.showsLoadingPlaceholder {
                loadingStrip
            }
        }
        .padding(.top, 2)
        .onAppear { viewModel.loadInitialMedia() }
        .fullScreenCover(item: $fullscreenVideoURL) { url in
            FullscreenVideoPlayerView(url: url)
        }
        .alert("Delete Photo", isPresented: deleteAlertBinding) {
            Button("Delete", role: .destructive) { confirmDeletePhoto() }
            Button("Cancel", role: .cancel) { photoToDelete = nil }
        } message: {
            Text("This photo will be permanently removed.")
        }
    }

    // MARK: - Strip

    /// Scrolling row of media tiles with leading padding.
    private func strip(_ content: PlaceMediaStripContent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: tileSpacing) {
                ForEach(Array(content.items.enumerated()), id: \.element.id) { index, item in
                    tile(for: item, in: content)
                        .onAppear { viewModel.loadMoreIfNeeded(at: index, itemCount: content.items.count) }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: tileHeight)
        .accessibilityIdentifier("place.detail.mediaStrip")
    }

    /// Renders the tile for a strip item according to what it opens.
    @ViewBuilder
    private func tile(for item: PlaceMediaStripItem, in content: PlaceMediaStripContent) -> some View {
        switch item.kind {
        case .externalVideo(let videoID):
            if let video = viewModel.externalVideo(withID: videoID) {
                externalVideoTile(video, item: item)
            }
        case .galleryVideo(let url):
            photoTile(item, onTap: { fullscreenVideoURL = URL(string: url) })
        case .photo(let galleryIndex):
            photoTile(item, onTap: { onPhotoTapped(content.photoURLs, galleryIndex) })
                .contextMenu {
                    if item.source == .externalReview {
                        Button(role: .destructive) { photoToDelete = item } label: {
                            Label("Delete Photo", systemImage: "trash")
                        }
                    }
                }
        }
    }

    /// Photo or gallery-video tile that hides itself when its image fails.
    private func photoTile(_ item: PlaceMediaStripItem, onTap: @escaping () -> Void) -> some View {
        PlaceMediaStripPhotoTile(
            item: item,
            size: CGSize(width: photoWidth, height: tileHeight),
            cornerRadius: cornerRadius,
            onTap: onTap,
            onLoadFailed: { viewModel.reportFailure(of: item) }
        )
        .accessibilityIdentifier("place.detail.mediaStrip.photo")
    }

    /// External video tile with play badge that hides itself when its thumbnail is unavailable.
    private func externalVideoTile(_ video: ExternalVideo, item: PlaceMediaStripItem) -> some View {
        ExternalVideoView(
            externalVideo: video,
            externalPlaceId: video.externalPlaceId,
            onDelete: { Task { await deleteVideo(video) } },
            showDeleteOption: video.savedByUserId == userSession.currentUserId,
            compactSize: CGSize(width: videoWidth, height: tileHeight),
            onThumbnailUnavailable: { viewModel.reportFailure(of: item) }
        )
        .id("video_\(video.videoID)")
        .accessibilityIdentifier("place.detail.mediaStrip.video")
    }

    // MARK: - Loading

    private var loadingStrip: some View {
        HStack(spacing: tileSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                ShimmerView()
                    .frame(width: photoWidth, height: tileHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: tileHeight, alignment: .leading)
        .accessibilityHidden(true)
    }

    // MARK: - Deletion

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { photoToDelete != nil }, set: { if !$0 { photoToDelete = nil } })
    }

    /// Deletes the photo pending confirmation.
    private func confirmDeletePhoto() {
        guard let item = photoToDelete else { return }
        photoToDelete = nil
        Task { await viewModel.deletePhoto(item) }
    }

    /// Deletes a video the current user saved.
    private func deleteVideo(_ video: ExternalVideo) async {
        guard let userId = userSession.currentUserId else { return }
        await viewModel.deleteVideo(video, placeId: placeId, userId: userId)
    }
}
