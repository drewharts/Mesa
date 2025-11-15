//
//  TikTokVideosViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Handles TikTok video fetching, state management, and deletion
//

import Foundation
import Combine

@MainActor
class TikTokVideosViewModel: ObservableObject {
    // MARK: - Published State
    @Published var videos: [TikTokVideo] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // MARK: - Dependencies (Services, not ViewModels)
    private let tikTokService: TikTokPlaceService
    
    // Temporary: Still need these until we fully refactor
    private let selectedPlaceVM: SelectedPlaceViewModel
    private let profileVM: ProfileViewModel
    
    // MARK: - Initialization
    init(tikTokService: TikTokPlaceService,
         selectedPlaceVM: SelectedPlaceViewModel,
         profileVM: ProfileViewModel) {
        self.tikTokService = tikTokService
        self.selectedPlaceVM = selectedPlaceVM
        self.profileVM = profileVM
    }
    
    // MARK: - Actions
    func loadVideos(for placeId: String) async {
        isLoading = true
        error = nil
        
        do {
            // Get place TikTok videos (from place data)
            let placeTikTokVideos = selectedPlaceVM.tiktokVideos
            
            // Get user TikTok videos (from external places)
            let userTikTokVideos = await profileVM.getTikTokVideos(for: placeId)
            
            // Combine and deduplicate based on videoID or URL
            var allVideos = placeTikTokVideos
            
            for userVideo in userTikTokVideos {
                // Check if this video already exists (by videoID or URL)
                let alreadyExists = allVideos.contains { existingVideo in
                    existingVideo.videoID == userVideo.videoID || existingVideo.url == userVideo.url
                }
                
                if !alreadyExists {
                    allVideos.append(userVideo)
                }
            }
            
            videos = allVideos
            isLoading = false
        } catch let loadError {
            error = loadError
            isLoading = false
            print("❌ Error loading TikTok videos: \(loadError)")
        }
    }
    
    func deleteVideo(_ video: TikTokVideo, placeId: String, userId: String) async {
        do {
            let videoUrl = video.url
            
            // Get the external_place_id for this video URL
            let externalPlaceId = await profileVM.getExternalPlaceId(for: placeId, videoUrl: videoUrl)
            
            try await tikTokService.deleteTikTokFromPlace(
                placeId: placeId,
                videoUrl: videoUrl,
                userId: userId,
                externalPlaceId: externalPlaceId
            )
            
            // Refresh TikTok videos for this place
            await loadVideos(for: placeId)
            
            // Refresh the profile to update the UI
            await profileVM.fetchUserExternalPlaces()
        } catch let deleteError {
            error = deleteError
            print("❌ Error deleting TikTok: \(deleteError)")
        }
    }
    
    // MARK: - Computed Properties
    var hasVideos: Bool {
        !videos.isEmpty
    }
    
    var videoCount: Int {
        videos.count
    }
}

