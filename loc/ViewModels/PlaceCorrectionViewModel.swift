//
//  PlaceCorrectionViewModel.swift
//  loc
//
//  Single Responsibility: Manages search and place assignment/correction for external videos.
//  Depends on Services (PlaceSearchService, UserService, SupabasePlaceService), not other ViewModels.

import SwiftUI

/// Determines whether the sheet corrects an existing place or assigns a brand-new one.
enum PlaceAssignmentMode {
    case correction(externalPlaceId: String, currentPlaceName: String)
    case correctionWithVideos(videos: [ExternalVideo], currentPlaceName: String)
    case newAssignment(contentUrl: String)
}

@MainActor
class PlaceCorrectionViewModel: ObservableObject {
    let mode: PlaceAssignmentMode

    @Published var searchText = ""
    @Published var searchResults: [MesaPlaceSuggestion] = []
    @Published var isSearching = false
    @Published var isUpdating = false
    @Published var errorMessage: String?
    @Published var didComplete = false
    @Published var selectedVideo: ExternalVideo?
    @Published var enrichedVideos: [ExternalVideo] = []

    /// The resolved DetailPlace after successful assignment (read by View on completion).
    private(set) var resolvedPlace: DetailPlace?

    private let searchService = PlaceSearchService()
    private let userService = UserService.shared
    private let externalContentService = ExternalContentService()

    /// Initializes the ViewModel with the assignment mode. Auto-selects when only one video exists.
    init(mode: PlaceAssignmentMode) {
        self.mode = mode

        if case .correctionWithVideos(let videos, _) = mode {
            self.enrichedVideos = videos
            // Auto-select when there's only one video so the selector step is skipped.
            if videos.count == 1 {
                self.selectedVideo = videos.first
            }
        }
    }

    /// Fetches thumbnail URLs for videos that have empty thumbnails via oEmbed.
    func loadVideoThumbnails() {
        guard case .correctionWithVideos(let videos, _) = mode else { return }

        for (index, video) in videos.enumerated() where video.thumbnailURL.isEmpty {
            Task {
                let result = await externalContentService.getTikTokOEmbed(url: video.url)
                if case .success(let oembed) = result, !oembed.thumbnailUrl.isEmpty {
                    var updated = self.enrichedVideos[index]
                    updated.thumbnailURL = oembed.thumbnailUrl
                    self.enrichedVideos[index] = updated
                }
            }
        }
    }

    /// True when the mode provides multiple videos and the user hasn't picked one yet.
    var needsVideoSelection: Bool {
        if case .correctionWithVideos(let videos, _) = mode {
            return videos.count > 1
        }
        return false
    }

    /// True when a video has been selected (or the mode doesn't require selection).
    var hasSelectedVideo: Bool {
        if case .correctionWithVideos = mode {
            return selectedVideo != nil
        }
        return true
    }

    /// Sets the selected video for the correction flow.
    func selectVideo(_ video: ExternalVideo) {
        selectedVideo = video
    }

    // MARK: - Computed Properties for Mode-Dependent UI

    /// Returns the navigation title based on mode.
    var navigationTitle: String {
        switch mode {
        case .correction, .correctionWithVideos: return "Change Place"
        case .newAssignment: return "Find Place"
        }
    }

    /// Returns the header label text based on mode.
    var headerLabelText: String {
        switch mode {
        case .correction, .correctionWithVideos: return "Current Place"
        case .newAssignment: return "No Place Detected"
        }
    }

    /// Returns the icon name for the header based on mode.
    var headerIconName: String {
        switch mode {
        case .correction, .correctionWithVideos: return "mappin.circle.fill"
        case .newAssignment: return "questionmark.circle.fill"
        }
    }

    /// Returns the header title based on mode.
    var headerTitle: String {
        switch mode {
        case .correction(_, let currentPlaceName): return currentPlaceName
        case .correctionWithVideos(_, let currentPlaceName): return currentPlaceName
        case .newAssignment: return "Unknown Place"
        }
    }

    /// Returns the header subtitle based on mode.
    var headerSubtitle: String {
        switch mode {
        case .correction, .correctionWithVideos: return "Search below to find the correct place"
        case .newAssignment: return "Search below to find the place in this video"
        }
    }

    // MARK: - Actions

    /// Searches for places matching the query via PlaceSearchService.
    func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        searchService.searchPlaces(
            query: query,
            onResultsUpdated: { [weak self] results in
                self?.searchResults = results
                self?.isSearching = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error
                self?.isSearching = false
            }
        )
    }

    /// Clears the search text and results.
    func clearSearch() {
        searchText = ""
        searchResults = []
    }

    /// Selects a suggestion, ensures the place exists in the DB, then persists the assignment.
    func selectPlace(_ suggestion: MesaPlaceSuggestion) {
        isUpdating = true
        errorMessage = nil

        searchService.selectSuggestion(
            suggestion,
            onError: { [weak self] error in
                self?.isUpdating = false
                self?.errorMessage = "Failed to load place details: \(error)"
            }
        ) { [weak self] detailPlace in
            guard let self = self else { return }
            Task {
                await self.persistPlaceAssignment(detailPlace: detailPlace)
            }
        }
    }

    /// Ensures the place exists in the places table and persists the external_places association.
    private func persistPlaceAssignment(detailPlace: DetailPlace) async {
        do {
            try await SupabasePlaceService.shared.ensurePlaceExists(place: detailPlace)

            let newPlaceId = detailPlace.id.uuidString

            guard let userId = SupabaseAuthService.shared.currentUserId else {
                errorMessage = "Unable to verify user identity"
                isUpdating = false
                return
            }

            switch mode {
            case .correction(let externalPlaceId, _):
                try await userService.updateExternalPlaceAssociation(
                    externalPlaceId: externalPlaceId,
                    newPlaceId: newPlaceId,
                    userId: userId
                )

            case .correctionWithVideos:
                guard let externalPlaceId = selectedVideo?.externalPlaceId else {
                    errorMessage = "No video selected for correction"
                    isUpdating = false
                    return
                }
                try await userService.updateExternalPlaceAssociation(
                    externalPlaceId: externalPlaceId,
                    newPlaceId: newPlaceId,
                    userId: userId
                )

            case .newAssignment(let contentUrl):
                try await userService.createExternalPlace(
                    userId: userId,
                    placeId: newPlaceId,
                    url: contentUrl
                )
            }

            resolvedPlace = detailPlace
            isUpdating = false
            didComplete = true
            NotificationCenter.default.post(name: .externalPlaceCorrected, object: nil)
        } catch {
            isUpdating = false
            errorMessage = "Failed to save place: \(error.localizedDescription)"
        }
    }
}

extension Notification.Name {
    /// Posted when a user corrects a TikTok/Instagram video's place association.
    static let externalPlaceCorrected = Notification.Name("externalPlaceCorrected")
}
