//
//  ListsPlacePaginationViewModel.swift
//  loc
//
//  Child ViewModel for pagination of places within individual lists.
//

import SwiftUI

/// Manages pagination of places within individual lists.
@MainActor
class ListsPlacePaginationViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Pagination state for places within each list.
    @Published var listPlacePagination: [String: ListPlacePagination] = [:]

    // MARK: - Dependencies

    private let placeService: PlaceService

    // MARK: - ViewModel References

    private weak var dataViewModel: ListsDataViewModel?

    // MARK: - Callbacks

    /// Called when places dictionary needs updating.
    var onPlacesUpdate: ((String, DetailPlace?) -> Void)?

    /// Called to fetch place image.
    var onFetchPlaceImage: ((String) -> Void)?

    // MARK: - Initialization

    /// Initializes the place pagination view model with required dependencies.
    init(placeService: PlaceService, dataViewModel: ListsDataViewModel) {
        self.placeService = placeService
        self.dataViewModel = dataViewModel
    }

    // MARK: - Pagination Management

    /// Reset pagination for a list (call when places are added/removed).
    func resetListPagination(listId: UUID) {
        guard let dataVM = dataViewModel else { return }

        let listIdString = listId.uuidString
        listPlacePagination.removeValue(forKey: listIdString)

        // Re-initialize pagination if the list has places
        if let placeIds = dataVM.userListsPlaces[listIdString], !placeIds.isEmpty {
            initializeListPagination(listId: listId)
        }
    }

    /// Initialize pagination state for a list.
    private func initializeListPagination(listId: UUID) {
        guard let dataVM = dataViewModel else { return }

        let listIdString = listId.uuidString
        guard let allPlaceIds = dataVM.userListsPlaces[listIdString], !allPlaceIds.isEmpty else {
            return
        }

        // Initialize pagination state
        var pagination = ListPlacePagination()
        pagination.allPlaceIds = allPlaceIds
        pagination.hasMorePlaces = allPlaceIds.count > pagination.placesPerPage

        // Store initial pagination before loading the first page
        listPlacePagination[listIdString] = pagination

        // Load first page
        loadNextPageForList(listId: listId)
    }

    /// Public method to initialize pagination if needed (called from views).
    func initializeListPaginationIfNeeded(listId: UUID) {
        let listIdString = listId.uuidString

        // Only initialize if not already initialized
        if listPlacePagination[listIdString] == nil {
            initializeListPagination(listId: listId)
        }
    }

    /// Load the next page of places for a specific list.
    func loadNextPageForList(listId: UUID) {
        let listIdString = listId.uuidString
        guard var pagination = listPlacePagination[listIdString],
              !pagination.isLoadingMore,
              pagination.hasMorePlaces else {
            return
        }

        pagination.isLoadingMore = true
        listPlacePagination[listIdString] = pagination

        let startIndex = pagination.currentPage * pagination.placesPerPage
        let endIndex = min(startIndex + pagination.placesPerPage, pagination.allPlaceIds.count)

        guard startIndex < pagination.allPlaceIds.count else {
            pagination.isLoadingMore = false
            pagination.hasMorePlaces = false
            listPlacePagination[listIdString] = pagination
            return
        }

        let placeIdsToLoad = Array(pagination.allPlaceIds[startIndex..<endIndex])

        Task {
            // Load place details for the new place IDs
            for placeId in placeIdsToLoad {
                do {
                    let detailPlace = try await placeService.fetchPlace(withId: placeId)
                    onPlacesUpdate?(placeId, detailPlace)
                    onFetchPlaceImage?(placeId)
                } catch {
                    print("❌ [ListsPlacePaginationViewModel] loadNextPageForList: Failed to load place \(placeId): \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                // Update pagination state
                if var updatedPagination = self.listPlacePagination[listIdString] {
                    updatedPagination.loadedPlaceIds.append(contentsOf: placeIdsToLoad)
                    updatedPagination.currentPage += 1
                    updatedPagination.isLoadingMore = false
                    updatedPagination.hasMorePlaces = endIndex < updatedPagination.allPlaceIds.count

                    self.listPlacePagination[listIdString] = updatedPagination
                }
            }
        }
    }

    // MARK: - Query Methods

    /// Get the displayed place IDs for a list (respecting pagination).
    func getDisplayedPlaceIds(for listId: UUID) -> [String] {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.displayedPlaceIds ?? []
    }

    /// Check if a list has more places to load.
    func hasMorePlaces(for listId: UUID) -> Bool {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.hasMorePlaces ?? false
    }

    /// Check if a list is currently loading more places.
    func isLoadingMorePlaces(for listId: UUID) -> Bool {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.isLoadingMore ?? false
    }

    /// Get the total number of places in a list.
    func getTotalPlaceCount(for listId: UUID) -> Int {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.totalPlaces ?? 0
    }

    // MARK: - Reset

    /// Resets all pagination state.
    func resetPaginationState() {
        listPlacePagination.removeAll()
    }
}
