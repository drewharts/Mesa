//
//  TikTokVideoView.swift
//  loc
//
//  Created by Mesa on 7/2/25.
//

import SwiftUI

struct TikTokVideoView: View {
    @StateObject private var viewModel: TikTokVideoViewModel
    @EnvironmentObject var userSession: UserSession
    @State private var refreshAttempted: Bool = false
    @State private var showingDeleteConfirmation = false

    // Optional place for navigation instead of opening video
    let associatedPlace: DetailPlace?
    let onNavigateToPlace: ((DetailPlace) -> Void)?
    let onDelete: (() -> Void)?
    let showDeleteOption: Bool

    /// Initializes the TikTok video view with video data and optional navigation callbacks.
    init(tikTokVideo: TikTokVideo, externalPlaceId: String? = nil, associatedPlace: DetailPlace? = nil, onNavigateToPlace: ((DetailPlace) -> Void)? = nil, onDelete: (() -> Void)? = nil, showDeleteOption: Bool = false) {
        _viewModel = StateObject(wrappedValue: TikTokVideoViewModel(tikTokVideo: tikTokVideo, externalPlaceId: externalPlaceId))
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
                TikTokWebView(embedHTML: viewModel.tikTokVideo.embedHTML, videoURL: viewModel.tikTokVideo.url)
                    .navigationBarHidden(true)
                    .ignoresSafeArea()
            }
        }
        .confirmationDialog("Delete TikTok", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this TikTok from your saved places?")
        }
        .onChange(of: viewModel.tikTokVideo.thumbnailURL) { oldValue, newValue in
            if oldValue != newValue {
                refreshAttempted = false
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
                urlString: viewModel.tikTokVideo.thumbnailURL,
                contentMode: .fill,
                frameSize: CGSize(width: 160, height: 160),
                cornerRadius: 8,
                onFailure: {
                    if !refreshAttempted {
                        refreshAttempted = true
                        Task {
                            await viewModel.refreshThumbnail()
                        }
                    }
                }
            )
            .id("\(viewModel.tikTokVideo.thumbnailURL)_\(viewModel.tikTokVideo.id)")
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
        Text(viewModel.tikTokVideo.author.username)
            .font(.caption)
            .foregroundColor(.gray)
            .frame(maxWidth: 192, alignment: .leading)
            .lineLimit(1)
    }
}

struct TikTokVideoView_Previews: PreviewProvider {
    static var previews: some View {
        TikTokVideoView(tikTokVideo: TikTokVideo(
            videoID: "sample123",
            url: "https://www.tiktok.com/t/ZP8hJe4ym/",
            title: "Amazing restaurant in NYC!",
            caption: "Check out this amazing Vietnamese restaurant in NYC! The food is incredible and authentic. #vietnamese #nyc #foodie #restaurant",
            embedHTML: "<blockquote class=\"tiktok-embed\">Sample embed</blockquote>",
            thumbnailURL: "https://example.com/thumbnail.jpg",
            author: TikTokAuthor(
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