//
//  TikTokPlaceCorrectionViewModel.swift
//  loc
//
//  Single Responsibility: Manages search and place assignment/correction for TikTok videos.
//  Depends on Services (PlaceSearchService, UserService, SupabasePlaceService), not other ViewModels.

import SwiftUI

/// Determines whether the sheet corrects an existing place or assigns a brand-new one.
enum TikTokPlaceAssignmentMode {
    case correction(externalPlaceId: String, currentPlaceName: String)
    case newAssignment(tikTokUrl: String)
}

@MainActor
class TikTokPlaceCorrectionViewModel: ObservableObject {
    let mode: TikTokPlaceAssignmentMode

    @Published var searchText = ""
    @Published var searchResults: [MesaPlaceSuggestion] = []
    @Published var isSearching = false
    @Published var isUpdating = false
    @Published var errorMessage: String?
    @Published var didComplete = false

    /// The resolved DetailPlace after successful assignment (read by View on completion).
    private(set) var resolvedPlace: DetailPlace?

    private let searchService = PlaceSearchService()
    private let userService = UserService.shared

    /// Initializes the ViewModel with the assignment mode.
    init(mode: TikTokPlaceAssignmentMode) {
        self.mode = mode
    }

    // MARK: - Computed Properties for Mode-Dependent UI

    /// Returns the navigation title based on mode.
    var navigationTitle: String {
        switch mode {
        case .correction: return "Change Place"
        case .newAssignment: return "Find Place"
        }
    }

    /// Returns the header label text based on mode.
    var headerLabelText: String {
        switch mode {
        case .correction: return "Current Place"
        case .newAssignment: return "No Place Detected"
        }
    }

    /// Returns the icon name for the header based on mode.
    var headerIconName: String {
        switch mode {
        case .correction: return "mappin.circle.fill"
        case .newAssignment: return "questionmark.circle.fill"
        }
    }

    /// Returns the header title based on mode.
    var headerTitle: String {
        switch mode {
        case .correction(_, let currentPlaceName): return currentPlaceName
        case .newAssignment: return "Unknown Place"
        }
    }

    /// Returns the header subtitle based on mode.
    var headerSubtitle: String {
        switch mode {
        case .correction: return "Search below to find the correct place"
        case .newAssignment: return "Search below to find the place in this TikTok"
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
                try await userService.updateTikTokPlaceAssociation(
                    externalPlaceId: externalPlaceId,
                    newPlaceId: newPlaceId,
                    userId: userId
                )

            case .newAssignment(let tikTokUrl):
                try await userService.createExternalPlace(
                    userId: userId,
                    placeId: newPlaceId,
                    url: tikTokUrl
                )
            }

            resolvedPlace = detailPlace
            isUpdating = false
            didComplete = true
        } catch {
            isUpdating = false
            errorMessage = "Failed to save place: \(error.localizedDescription)"
        }
    }
}
