//
//  TikTokVideosSection.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Smart component with its own ViewModel for TikTok video display
//

import SwiftUI

struct TikTokVideosSection: View {
    @ObservedObject var viewModel: TikTokVideosViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession

    let placeId: String
    let selectedPlace: DetailPlace?

    /// Callback when user changes the place association - parent should navigate to new place
    var onPlaceChanged: ((String) -> Void)?

    @State private var showChangePlaceSheet = false

    // MARK: - Computed Properties

    /// Find TikTok video saved by current user (for Change Place functionality)
    private var currentUserVideo: TikTokVideo? {
        viewModel.videos.first { $0.savedByUserId == userSession.currentUserId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.hasVideos {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("TikTok Videos")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("\(viewModel.videoCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.videos, id: \.videoID) { video in
                                // Only show delete option if current user saved this video
                                let canDelete = video.savedByUserId == userSession.currentUserId
                                TikTokVideoView(
                                    tikTokVideo: video,
                                    externalPlaceId: video.externalPlaceId,
                                    onDelete: {
                                        Task {
                                            await deleteVideo(video)
                                        }
                                    },
                                    showDeleteOption: canDelete
                                )
                                .id("tiktok_\(video.videoID)")
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                .padding(.top, 15)
                
                // TikTok Place Flagging (only for TikTok places)
                if profile.hasTikTokVideos(for: placeId) {
                    if let place = selectedPlace {
                        TikTokPlaceFlaggingView(place: place)
                            .environmentObject(profile)
                            .padding(.top, 15)
                    }
                }

                // Change Place option (only show if current user saved this TikTok)
                if currentUserVideo != nil {
                    changePlaceButton
                }
            }
        }
        .task(id: placeId) {
            await viewModel.loadVideos(for: placeId)
        }
        .sheet(isPresented: $showChangePlaceSheet) {
            if let place = selectedPlace, let video = currentUserVideo {
                TikTokPlaceCorrectionSheet(
                    placeId: placeId,
                    placeName: place.name,
                    externalPlaceId: video.externalPlaceId,
                    onPlaceChanged: onPlaceChanged
                )
                .environmentObject(profile)
            }
        }
    }

    // MARK: - Change Place Button
    private var changePlaceButton: some View {
        Button {
            showChangePlaceSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                Text("Wrong place? Search for correct place")
                    .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .padding(.top, 12)
    }
    
    // MARK: - Private Actions
    private func deleteVideo(_ video: TikTokVideo) async {
        guard let userId = userSession.currentUserId else { return }
        await viewModel.deleteVideo(video, placeId: placeId, userId: userId)
    }
}

// MARK: - Preview
#Preview {
    let services = ServiceContainer.shared
    let locationManager = LocationManager()
    
    let detailPlaceVM = DetailPlaceViewModel(
        placeService: services.placeService,
        userService: services.userService
    )
    
    let selectedPlaceVM = SelectedPlaceViewModel(
        locationManager: locationManager,
        postService: services.postService,
        placeService: services.placeService,
        userService: services.userService,
        imageService: services.imageService,
        detailPlaceViewModel: detailPlaceVM
    )
    
    let userSession = UserSession(
        userService: services.userService,
        locationManager: locationManager,
        detailPlaceVM: detailPlaceVM
    )
    
    let profileVM = ProfileViewModel(
        userSession: userSession,
        userService: services.userService,
        detailPlaceViewModel: detailPlaceVM,
        imageService: services.imageService,
        placeService: services.placeService,
        postService: services.postService,
        locationManager: locationManager,
        deepLinkManager: services.deepLinkManager,
        deepLinkViewModel: nil
    )
    
    let tikTokVM = TikTokVideosViewModel(
        tikTokService: TikTokPlaceService.shared,
        selectedPlaceVM: selectedPlaceVM,
        profileVM: profileVM
    )
    
    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"
    
    return TikTokVideosSection(
        viewModel: tikTokVM,
        placeId: "test-place-123",
        selectedPlace: mockPlace
    )
    .environmentObject(profileVM)
    .environmentObject(userSession)
    .padding()
}

