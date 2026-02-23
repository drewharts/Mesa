//
//  ExternalVideosViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Handles external video fetching, state management, and deletion
//

import Foundation
import Combine

@MainActor
class ExternalVideosViewModel: ObservableObject {
    // MARK: - Published State
    @Published var videos: [ExternalVideo] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Dependencies (Services only)
    private let externalContentService: ExternalPlaceService

    // MARK: - Callbacks
    /// Called after a video is deleted so parent can refresh external places
    var onVideoDeleted: (() -> Void)?

    // MARK: - Private State
    private var currentPlaceId: String?
    private var placeVideos: [ExternalVideo] = []
    private var userVideos: [ExternalVideo] = []

    // MARK: - Initialization
    /// Initializes the ViewModel with external content service dependency.
    init(externalContentService: ExternalPlaceService = ExternalPlaceService.shared) {
        self.externalContentService = externalContentService
    }

    // MARK: - Data-Driven Methods

    /// Sets the current place ID and resets video state.
    func setPlaceId(_ placeId: String?) {
        currentPlaceId = placeId
        if placeId == nil {
            videos = []
            placeVideos = []
            userVideos = []
        }
    }

    /// Sets the place-associated external videos and combines with user videos.
    func setPlaceVideos(_ videos: [ExternalVideo]) {
        placeVideos = videos
        combineAndDeduplicateVideos()
    }

    /// Sets the user's external videos for the current place and combines with place videos.
    func setUserVideos(_ videos: [ExternalVideo]) {
        userVideos = videos
        combineAndDeduplicateVideos()
    }

    // MARK: - Actions

    /// Combines place and user videos, removing duplicates based on videoID or URL.
    private func combineAndDeduplicateVideos() {
        var allVideos = placeVideos

        for userVideo in userVideos {
            let alreadyExists = allVideos.contains { existingVideo in
                existingVideo.videoID == userVideo.videoID || existingVideo.url == userVideo.url
            }

            if !alreadyExists {
                allVideos.append(userVideo)
            }
        }

        videos = allVideos
    }

    /// Deletes an external video from a place, verifying ownership first.
    func deleteVideo(_ video: ExternalVideo, placeId: String, userId: String) async {
        do {
            // Security: Verify user owns this video before deletion
            guard video.savedByUserId == userId else {
                print("❌ [ExternalVideosViewModel] Cannot delete video - user doesn't own it")
                error = NSError(
                    domain: "ExternalVideosViewModel",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "You can only delete your own videos"]
                )
                return
            }

            let videoUrl = video.url
            let externalPlaceId = video.externalPlaceId

            try await externalContentService.deleteVideoFromPlace(
                placeId: placeId,
                videoUrl: videoUrl,
                userId: userId,
                externalPlaceId: externalPlaceId
            )

            // Remove from local state
            videos.removeAll { $0.url == video.url }
            userVideos.removeAll { $0.url == video.url }

            // Notify parent to refresh external places
            onVideoDeleted?()
        } catch let deleteError {
            error = deleteError
            print("❌ Error deleting video: \(deleteError)")
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

