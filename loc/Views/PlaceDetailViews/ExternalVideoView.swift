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

    /// Initializes the external video view with video data and optional navigation callbacks.
    init(externalVideo: ExternalVideo, externalPlaceId: String? = nil, associatedPlace: DetailPlace? = nil, onNavigateToPlace: ((DetailPlace) -> Void)? = nil, onDelete: (() -> Void)? = nil, showDeleteOption: Bool = false) {
        _viewModel = StateObject(wrappedValue: ExternalVideoViewModel(externalVideo: externalVideo, externalPlaceId: externalPlaceId))
        self.associatedPlace = associatedPlace
        self.onNavigateToPlace = onNavigateToPlace
        self.onDelete = onDelete
        self.showDeleteOption = showDeleteOption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            videoThumbnailButton
            authorInfoSection
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

    private var videoThumbnailButton: some View {
        ZStack {
            // Background that matches the tap area
            Color(.systemGray6)
                .cornerRadius(12)

            // Image content
            CustomImageLoader(
                urlString: viewModel.externalVideo.thumbnailURL,
                contentMode: .fill,
                frameSize: CGSize(width: 160, height: 160),
                cornerRadius: 8,
                onFailure: {
                    if !refreshAttempted {
                        refreshAttempted = true
                        isRefreshingThumbnail = true
                        Task {
                            await viewModel.refreshThumbnail()
                            // If URL didn't change, refresh failed - stop showing loading
                            await MainActor.run {
                                isRefreshingThumbnail = false
                            }
                        }
                    }
                }
            )
            .id("\(viewModel.externalVideo.thumbnailURL)_\(viewModel.externalVideo.id)")

            // Show loading overlay while refreshing thumbnail (opaque to hide failure state)
            if isRefreshingThumbnail {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(width: 160, height: 160)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .frame(width: 192, height: 192) // Match the visual size
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
