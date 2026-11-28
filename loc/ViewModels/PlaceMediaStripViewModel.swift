//
//  PlaceMediaStripViewModel.swift
//  loc
//
//  Drives the horizontal photo + video strip on place detail. Merges the photos and external
//  videos view models into one list of tiles and hides tiles that fail to load.
//

import Foundation
import Combine

@MainActor
class PlaceMediaStripViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var failedIDs: Set<String> = []

    // MARK: - Dependencies
    private let photosViewModel: PlacePhotosViewModel
    private let videosViewModel: ExternalVideosViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    /// Creates the strip view model over the photo and video view models it merges.
    init(photosViewModel: PlacePhotosViewModel, videosViewModel: ExternalVideosViewModel) {
        self.photosViewModel = photosViewModel
        self.videosViewModel = videosViewModel
        photosViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        videosViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Derived State

    /// Current strip tiles and gallery URLs.
    var content: PlaceMediaStripContent {
        PlaceMediaStripContent.make(
            photos: photosViewModel.combinedPhotoItems,
            videos: videosViewModel.videos,
            failedIDs: failedIDs
        )
    }

    /// External video for a tile, used to open or delete it.
    func externalVideo(withID videoID: String) -> ExternalVideo? {
        videosViewModel.videos.first { $0.videoID == videoID }
    }

    /// Whether to show a loading shimmer because nothing has loaded yet.
    var showsLoadingPlaceholder: Bool {
        videosViewModel.isLoading || photosViewModel.isAnyPhotosLoading
    }

    // MARK: - Actions

    /// Clears per-place state (failed tiles) when the place changes.
    func reset() {
        failedIDs = []
    }

    /// Starts loading photos shown in the strip.
    func loadInitialMedia() {
        photosViewModel.loadInitialExternalReviewPhotos()
    }

    /// Hides a tile whose image failed to load and lets the photo VM try a backend refresh.
    func reportFailure(of item: PlaceMediaStripItem) {
        failedIDs.insert(item.id)
        if case .photo = item.kind {
            photosViewModel.reportExternalImageLoadFailure(url: item.thumbnailURL)
        }
    }

    /// Loads more photos when the tile at `index` is near the end of the strip.
    func loadMoreIfNeeded(at index: Int, itemCount: Int) {
        guard index >= itemCount - 3 else { return }
        photosViewModel.loadMorePhotos()
        photosViewModel.loadMoreExternalReviewPhotosIfNeeded(currentIndex: index)
    }

    /// Deletes an external review photo the user is allowed to remove.
    func deletePhoto(_ item: PlaceMediaStripItem) async {
        await photosViewModel.deleteExternalReviewPhoto(url: item.thumbnailURL)
    }

    /// Deletes an external video the user saved.
    func deleteVideo(_ video: ExternalVideo, placeId: String, userId: String) async {
        await videosViewModel.deleteVideo(video, placeId: placeId, userId: userId)
    }
}
