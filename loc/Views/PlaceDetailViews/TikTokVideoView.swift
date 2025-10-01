//
//  TikTokVideoView.swift
//  loc
//
//  Created by Mesa on 7/2/25.
//

import SwiftUI

struct TikTokVideoView: View {
    @StateObject private var viewModel: TikTokVideoViewModel
    @State private var refreshAttempted: Bool = false
    @State private var isPressed: Bool = false
    
    init(tikTokVideo: TikTokVideo) {
        _viewModel = StateObject(wrappedValue: TikTokVideoViewModel(tikTokVideo: tikTokVideo))
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
        .onChange(of: viewModel.tikTokVideo.thumbnailURL) { oldValue, newValue in
            if oldValue != newValue {
                refreshAttempted = false
            }
        }
    }
    
    private var videoThumbnailButton: some View {
        ZStack {
            // Background that matches the tap area
            Color(isPressed ? .systemGray4 : .systemGray6)
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
            .opacity(isPressed ? 0.7 : 1.0)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .frame(width: 192, height: 192) // Match the visual size
        .contentShape(Rectangle()) // Make the entire frame tappable
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                    viewModel.openVideo()
                }
        )
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