//
//  AddPlaceToTripViewModel.swift
//  loc
//
//  Coordinator ViewModel for the Add Place to Trip sheet.
//  Single Responsibility: Manage browsing saved places and searching for new ones to add to a trip.
//

import Foundation
import Combine
import SwiftUI

/// Typed confirmation for trip place add/remove toast display.
struct TripPlaceConfirmation: Equatable {
    enum ActionType {
        case added
        case removed
    }

    let message: String
    let type: ActionType
}

@MainActor
class AddPlaceToTripViewModel: ObservableObject {

    // MARK: - Tab Selection

    enum Tab: String, CaseIterable {
        case browse = "Your Places"
        case search = "Search"
    }

    // MARK: - Published State

    @Published var selectedTab: Tab = .browse
    @Published var lists: [LightweightPlaceList] = []
    @Published var listSearchText: String = ""
    @Published var listPreviewPlaces: [String: [LightweightPlace]] = [:]
    @Published var placeColors: [UUID: Color] = [:]
    @Published var selectedListPlaces: [LightweightPlace] = []
    @Published var searchResults: [MesaPlaceSuggestion] = []
    @Published var placesInTrip: Set<String> = []
    @Published var addedSuggestionIds: Set<String> = []
    @Published var isLoadingInitial = false
    @Published var isLoadingListPlaces = false
    @Published var isAddingPlace: Set<String> = []
    @Published var searchText: String = ""
    @Published var isSearching = false
    @Published var errorMessage: String?

    // MARK: - Confirmation Toast State

    @Published var confirmation: TripPlaceConfirmation?

    /// Returns lists filtered by the list search text, or all lists if search is empty.
    var filteredLists: [LightweightPlaceList] {
        let query = listSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return lists }
        return lists.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Callback to dismiss the sheet and navigate to place detail.
    var onViewPlaceDetail: ((String) -> Void)?

    // MARK: - Dependencies

    private let tripId: String
    private let targetDayIndex: Int?
    private let userId: String
    private let tripService = TripService.shared
    private let placeListService = PlaceListService.shared
    private let searchService = PlaceSearchService()

    private var searchTask: Task<Void, Never>?
    private var confirmationDismissTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initializes the ViewModel with trip context and existing place IDs for duplicate detection.
    init(tripId: String, targetDayIndex: Int?, existingPlaceIds: Set<String>, userId: String) {
        self.tripId = tripId
        self.targetDayIndex = targetDayIndex
        self.userId = userId
        self.placesInTrip = existingPlaceIds
    }

    // MARK: - Load Initial Data

    /// Fetches the user's lists and preview places for collage thumbnails.
    func loadInitialData() async {
        isLoadingInitial = true
        errorMessage = nil

        do {
            lists = try await placeListService.fetchListsByProximity(
                userId: userId,
                latitude: 0,
                longitude: 0,
                page: 1,
                pageSize: 500
            )
        } catch {
            errorMessage = "Failed to load your lists"
            print("[AddPlaceToTripVM] Failed to load initial data: \(error)")
        }

        isLoadingInitial = false

        await loadListPreviewPlaces()
    }

    /// Loads the first 3 places for each list in parallel for collage thumbnails.
    private func loadListPreviewPlaces() async {
        await withTaskGroup(of: (String, [LightweightPlace]).self) { group in
            for list in lists {
                group.addTask { [placeListService] in
                    let places = (try? await placeListService.fetchPlacesInList(
                        listId: list.list_id,
                        page: 1,
                        pageSize: 3
                    )) ?? []
                    return (list.list_id, places)
                }
            }
            for await (listId, places) in group {
                listPreviewPlaces[listId] = places
            }
        }
    }

    // MARK: - List Drill-Down

    /// Fetches places within a specific list for the drill-down view.
    func loadPlacesForList(listId: String) async {
        isLoadingListPlaces = true
        selectedListPlaces = []

        do {
            selectedListPlaces = try await placeListService.fetchPlacesInList(
                listId: listId,
                page: 1,
                pageSize: 100
            )
        } catch {
            print("[AddPlaceToTripVM] Failed to load list places: \(error)")
        }

        isLoadingListPlaces = false
    }

    // MARK: - Add Saved Place

    /// Adds a place (from favorites or a list) to the trip at the target day index.
    func addSavedPlace(placeId: String) async {
        guard !placesInTrip.contains(placeId) else { return }

        // Optimistic update
        isAddingPlace.insert(placeId)
        placesInTrip.insert(placeId)

        do {
            if let dayIndex = targetDayIndex {
                try await tripService.addPlaceToDay(
                    tripId: tripId,
                    placeId: placeId,
                    dayIndex: dayIndex,
                    addedBy: userId
                )
            } else {
                try await tripService.addPlaceAsIdea(
                    tripId: tripId,
                    placeId: placeId,
                    addedBy: userId
                )
            }
            showConfirmation("Added to trip", type: .added)
        } catch {
            // Revert optimistic update on failure
            placesInTrip.remove(placeId)
            errorMessage = "Failed to add place"
            print("[AddPlaceToTripVM] Failed to add place: \(error)")
        }

        isAddingPlace.remove(placeId)
    }

    // MARK: - Remove Saved Place

    /// Removes a previously added place from the trip.
    func removeSavedPlace(placeId: String) async {
        guard placesInTrip.contains(placeId) else { return }

        placesInTrip.remove(placeId)

        do {
            try await tripService.removePlaceFromTrip(tripId: tripId, placeId: placeId)
        } catch {
            placesInTrip.insert(placeId)
            errorMessage = "Failed to remove place"
            print("[AddPlaceToTripVM] Failed to remove place: \(error)")
        }
    }

    // MARK: - Search

    /// Performs a debounced search for places matching the query.
    func search(query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            searchService.searchPlaces(
                query: query,
                onResultsUpdated: { [weak self] results in
                    guard let self else { return }
                    Task { @MainActor in
                        self.searchResults = results
                        self.isSearching = false
                    }
                },
                onError: { [weak self] error in
                    guard let self else { return }
                    Task { @MainActor in
                        self.errorMessage = error
                        self.isSearching = false
                    }
                }
            )
        }
    }

    // MARK: - Search and Add

    /// Resolves a search suggestion to a full place and adds it to the trip.
    func searchAndAddPlace(suggestion: MesaPlaceSuggestion) async {
        let suggestionId = suggestion.id
        guard !isAddingPlace.contains(suggestionId) else { return }

        isAddingPlace.insert(suggestionId)
        errorMessage = nil

        do {
            let mesaBackendService = MesaBackendService()
            let detailPlace = try await mesaBackendService.fetchPlaceDetails(
                placeId: suggestion.id,
                source: suggestion.source
            )
            let placeId = detailPlace.id.uuidString
            placesInTrip.insert(placeId)

            do {
                if let dayIndex = targetDayIndex {
                    try await tripService.addPlaceToDay(
                        tripId: tripId,
                        placeId: placeId,
                        dayIndex: dayIndex,
                        addedBy: userId
                    )
                } else {
                    try await tripService.addPlaceAsIdea(
                        tripId: tripId,
                        placeId: placeId,
                        addedBy: userId
                    )
                }
                addedSuggestionIds.insert(suggestionId)
                showConfirmation("Added to trip", type: .added)
            } catch {
                placesInTrip.remove(placeId)
                addedSuggestionIds.remove(suggestionId)
                errorMessage = "Failed to add place"
                print("[AddPlaceToTripVM] Failed to add search place: \(error)")
            }
        } catch {
            errorMessage = "Failed to add place"
            print("[AddPlaceToTripVM] Failed to fetch place details: \(error)")
        }

        isAddingPlace.remove(suggestionId)
    }

    /// Clears the search state.
    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
    }

    // MARK: - Confirmation Toast

    /// Shows a confirmation toast and auto-clears it after 1.5 seconds.
    private func showConfirmation(_ message: String, type: TripPlaceConfirmation.ActionType) {
        confirmationDismissTask?.cancel()
        confirmation = TripPlaceConfirmation(message: message, type: type)
        confirmationDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled {
                self?.confirmation = nil
            }
        }
    }
}
