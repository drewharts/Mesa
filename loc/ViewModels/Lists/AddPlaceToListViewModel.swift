//
//  AddPlaceToListViewModel.swift
//  loc
//
//  Single Responsibility: Handle searching for places and adding them to a specific list.
//  Fetches its own dependencies from ServiceContainer.
//

import Foundation
import Combine

@MainActor
class AddPlaceToListViewModel: ObservableObject {

    // MARK: - Published State

    @Published var searchText: String = ""
    @Published var searchResults: [MesaPlaceSuggestion] = []
    @Published var isSearching: Bool = false
    @Published var isAddingPlace: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var addedPlaceId: String?

    // MARK: - Dependencies

    private let listId: String
    private let userId: String
    private let searchService = PlaceSearchService()
    private let userService: UserService

    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initializes the ViewModel with the target list ID and current user ID.
    init(listId: String, userId: String) {
        self.listId = listId
        self.userId = userId
        self.userService = ServiceContainer.shared.userService
    }

    // MARK: - Public Methods

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
            // Debounce: wait 300ms before searching
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            searchService.searchPlaces(
                query: query,
                onResultsUpdated: { [weak self] results in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.searchResults = results
                        self.isSearching = false
                    }
                },
                onError: { [weak self] error in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.errorMessage = error
                        self.isSearching = false
                    }
                }
            )
        }
    }

    /// Clears the current search state.
    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
    }

    /// Selects a place suggestion and adds it to the list.
    func selectAndAddPlace(_ suggestion: MesaPlaceSuggestion) {
        isAddingPlace = true
        errorMessage = nil
        successMessage = nil

        // First get the full place details
        searchService.selectSuggestion(suggestion) { [weak self] detailPlace in
            guard let self = self else { return }
            Task { @MainActor in
                await self.addPlaceToList(detailPlace)
            }
        }
    }

    // MARK: - Private Methods

    /// Adds the place to the list via the user service.
    private func addPlaceToList(_ place: DetailPlace) async {
        do {
            let placeId = place.id.uuidString

            // Check if place already exists in the list
            let alreadyInList = try await checkIfPlaceInList(placeId: placeId)

            if alreadyInList {
                errorMessage = "\(place.name) is already in this list"
                isAddingPlace = false
                return
            }

            // Add the place to the list
            try await userService.addPlaceToList(
                listId: listId,
                placeId: placeId,
                addedBy: userId
            )

            successMessage = "Added \(place.name) to list"
            addedPlaceId = placeId
            isAddingPlace = false

            // Clear search after successful add
            clearSearch()

        } catch {
            errorMessage = "Failed to add place: \(error.localizedDescription)"
            isAddingPlace = false
        }
    }

    /// Checks if a place is already in the list.
    private func checkIfPlaceInList(placeId: String) async throws -> Bool {
        return try await PlaceListService.shared.isPlaceInList(listId: listId, placeId: placeId)
    }
}
