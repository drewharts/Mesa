//
//  ExternalVideoView.swift
//  loc
//
//  Created by Mesa on 7/2/25.
//

import SwiftUI

struct ExternalVideoView: View {
    @StateObject private var viewModel: ExternalVideoViewModel
    @EnvironmentObject var userSession: UserSession
    @State private var refreshAttempted: Bool = false
    @State private var isRefreshingThumbnail: Bool = false
    @State private var showingDeleteConfirmation = false

    // Optional place for navigation instead of opening video
    let associatedPlace: DetailPlace?
    let onNavigateToPlace: ((DetailPlace) -> Void)?
    let onDelete: (() -> Void)?
    let showDeleteOption: Bool
    /// When set, renders a bare strip tile of this size (play badge, no author line, no gray backing).
    let compactSize: CGSize?
    /// Called in compact mode once the thumbnail cannot be loaded even after a refresh, so the tile can be hidden.
    let onThumbnailUnavailable: (() -> Void)?

    /// Initializes the external video view with video data and optional navigation callbacks.
    init(externalVideo: ExternalVideo, externalPlaceId: String? = nil, associatedPlace: DetailPlace? = nil, onNavigateToPlace: ((DetailPlace) -> Void)? = nil, onDelete: (() -> Void)? = nil, showDeleteOption: Bool = false, compactSize: CGSize? = nil, onThumbnailUnavailable: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ExternalVideoViewModel(externalVideo: externalVideo, externalPlaceId: externalPlaceId))
        self.associatedPlace = associatedPlace
        self.onNavigateToPlace = onNavigateToPlace
        self.onDelete = onDelete
        self.showDeleteOption = showDeleteOption
        self.compactSize = compactSize
        self.onThumbnailUnavailable = onThumbnailUnavailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            videoThumbnailButton
            if compactSize == nil {
                authorInfoSection
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingFullVideo) {
            NavigationView {
                ExternalWebView(embedHTML: viewModel.externalVideo.embedHTML, videoURL: viewModel.externalVideo.url)
                    .navigationBarHidden(true)
                    .ignoresSafeArea()
            }
        }
        .confirmationDialog("Delete Video", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this video from your saved places?")
        }
        .onChange(of: viewModel.externalVideo.thumbnailURL) { oldValue, newValue in
            if oldValue != newValue {
                refreshAttempted = false
                isRefreshingThumbnail = false
            }
        }
    }

    /// Edge sizes for the thumbnail image, its backing frame and corner radius.
    private var tileMetrics: (image: CGSize, frame: CGSize, radius: CGFloat) {
        if let compactSize { return (compactSize, compactSize, 8) }
        return (CGSize(width: 160, height: 160), CGSize(width: 192, height: 192), 8)
    }

    /// Play badge shown over compact strip tiles.
    @ViewBuilder
    private var playBadge: some View {
        if compactSize != nil {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 3)
                .allowsHitTesting(false)
        }
    }

    /// Refreshes an expired thumbnail once, then reports it unavailable if it still cannot load.
    private func handleThumbnailFailure() {
        guard !refreshAttempted else {
            onThumbnailUnavailable?()
            return
        }
        refreshAttempted = true
        isRefreshingThumbnail = true
        let previousURL = viewModel.externalVideo.thumbnailURL
        Task {
            await viewModel.refreshThumbnail()
            await MainActor.run {
                isRefreshingThumbnail = false
                if viewModel.externalVideo.thumbnailURL == previousURL {
                    onThumbnailUnavailable?()
                }
            }
        }
    }

    private var videoThumbnailButton: some View {
        ZStack {
            // Background that matches the tap area (strip tiles have none)
            if compactSize == nil {
                Color(.systemGray6)
                    .cornerRadius(12)
            }

            // Image content
            CustomImageLoader(
                urlString: viewModel.externalVideo.thumbnailURL,
                contentMode: .fill,
                frameSize: tileMetrics.image,
                cornerRadius: tileMetrics.radius,
                onFailure: handleThumbnailFailure
            )
            .id("\(viewModel.externalVideo.thumbnailURL)_\(viewModel.externalVideo.id)")

            // Show loading overlay while refreshing thumbnail (opaque to hide failure state)
            if isRefreshingThumbnail {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(width: tileMetrics.image.width, height: tileMetrics.image.height)
                    .cornerRadius(tileMetrics.radius)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }

            playBadge
        }
        .frame(width: tileMetrics.frame.width, height: tileMetrics.frame.height) // Match the visual size
        .contentShape(Rectangle()) // Make the entire frame tappable
        .onTapGesture {
            // Regular tap - open video or navigate
            if let place = associatedPlace, let onNavigate = onNavigateToPlace {
                onNavigate(place)
            } else {
                viewModel.openVideo()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press - show delete option
            if showDeleteOption {
                showingDeleteConfirmation = true
            }
        }
    }

    private var authorInfoSection: some View {
        Text(viewModel.externalVideo.author.username)
            .font(.caption)
            .foregroundColor(.gray)
            .frame(maxWidth: 192, alignment: .leading)
            .lineLimit(1)
    }
}

struct ExternalVideoView_Previews: PreviewProvider {
    static var previews: some View {
        ExternalVideoView(externalVideo: ExternalVideo(
            videoID: "sample123",
            url: "https://www.tiktok.com/t/ZP8hJe4ym/",
            title: "Amazing restaurant in NYC!",
            caption: "Check out this amazing Vietnamese restaurant in NYC! The food is incredible and authentic. #vietnamese #nyc #foodie #restaurant",
            embedHTML: "<blockquote class=\"tiktok-embed\">Sample embed</blockquote>",
            thumbnailURL: "https://example.com/thumbnail.jpg",
            author: ExternalVideoAuthor(
                displayName: "Food Lover",
                url: "https://www.tiktok.com/@foodlover",
                username: "foodlover"
            ),
            hashtags: ["vietnamese", "nyc", "foodie", "restaurant"],
            createdAt: "2025-07-02T23:30:00Z"
        ))
        .padding()
    }
}
