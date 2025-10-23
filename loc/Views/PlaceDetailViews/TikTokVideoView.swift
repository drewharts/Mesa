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
    @State private var showingDeleteConfirmation = false
    @State private var associatedPlaces: [TikTokAssociatedPlace] = []
    @State private var isLoadingPlaces = false

    // Optional place for navigation instead of opening video
    let associatedPlace: DetailPlace?
    let onNavigateToPlace: ((DetailPlace) -> Void)?
    let onDelete: (() -> Void)?
    let showDeleteOption: Bool

    init(tikTokVideo: TikTokVideo, associatedPlace: DetailPlace? = nil, onNavigateToPlace: ((DetailPlace) -> Void)? = nil, onDelete: (() -> Void)? = nil, showDeleteOption: Bool = false) {
        _viewModel = StateObject(wrappedValue: TikTokVideoViewModel(tikTokVideo: tikTokVideo))
        self.associatedPlace = associatedPlace
        self.onNavigateToPlace = onNavigateToPlace
        self.onDelete = onDelete
        self.showDeleteOption = showDeleteOption
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            videoThumbnailButton
            
            // Show associated places if any
            if !associatedPlaces.isEmpty {
                associatedPlacesView
            }
            
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
        .task {
            await loadAssociatedPlaces()
        }
    }
    
    private var associatedPlacesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(associatedPlaces.count) place\(associatedPlaces.count > 1 ? "s" : "")")
                .font(.caption2)
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(associatedPlaces) { place in
                        Button(action: {
                            // Navigate to this place
                            if let onNavigate = onNavigateToPlace {
                                // Would need to convert TikTokAssociatedPlace to DetailPlace
                                // For now just show the place
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if let address = place.address {
                                    Text(address)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .frame(maxWidth: 192)
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
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Long press - show delete option
                    if showDeleteOption {
                        showingDeleteConfirmation = true
                    }
                }
                .simultaneously(with: TapGesture()
                    .onEnded { _ in
                        // Regular tap - open video or navigate
                        if let place = associatedPlace, let onNavigate = onNavigateToPlace {
                            onNavigate(place)
                        } else {
                            viewModel.openVideo()
                        }
                    }
                )
        )
        .simultaneousGesture(
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
    
    private func loadAssociatedPlaces() async {
        guard !isLoadingPlaces, let userId = UserSession.shared.currentUserId else { return }
        
        isLoadingPlaces = true
        
        do {
            let places = try await TikTokPlaceService.shared.fetchPlacesForTikTok(
                videoId: viewModel.tikTokVideo.videoID,
                userId: userId
            )
            
            await MainActor.run {
                self.associatedPlaces = places
                self.isLoadingPlaces = false
            }
        } catch {
            print("❌ Error loading associated places for TikTok: \(error)")
            await MainActor.run {
                self.isLoadingPlaces = false
            }
        }
    }
}

// MARK: - Associated Place Model
struct TikTokAssociatedPlace: Identifiable, Codable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "place_id"
        case name = "place_name"
        case address = "place_address"
        case latitude
        case longitude
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