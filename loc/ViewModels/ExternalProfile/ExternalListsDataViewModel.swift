//
//  ExternalListsDataViewModel.swift
//  loc
//
//  Child ViewModel for external profile list data storage.
//  Handles list and place data with deduplication support.
//

import SwiftUI

/// Manages list data storage for external user profiles.
@MainActor
class ExternalListsDataViewModel: ObservableObject {
    // MARK: - Published Properties

    /// User's place lists.
    @Published var userLists: [LightweightPlaceList] = []

    /// Places in each list by list ID.
    @Published var placeListPlaces: [String: [LightweightPlace]] = [:]

    /// Whether there are more lists to load.
    @Published var hasMoreLists: Bool = true

    // MARK: - Pagination State

    /// Current page for list pagination.
    var currentListPage: Int = 1

    // MARK: - Pagination Constants

    /// Number of lists per page.
    let listsPerPage: Int = 6

    // MARK: - Deduplication

    /// Appends lists with deduplication.
    func appendLists(_ newLists: [LightweightPlaceList], nextPage: Int) {
        guard !newLists.isEmpty else {
            hasMoreLists = false
            return
        }

        let existingIds = Set(userLists.map { $0.list_id })
        let uniqueNewLists = newLists.filter { !existingIds.contains($0.list_id) }

        if !uniqueNewLists.isEmpty {
            userLists.append(contentsOf: uniqueNewLists)
            currentListPage = nextPage
        }

        hasMoreLists = newLists.count >= listsPerPage
    }

    /// Sets places for a list with deduplication.
    func setPlacesForList(listId: String, places: [LightweightPlace]) {
        var seenIds = Set<String>()
        let uniquePlaces = places.filter { place in
            guard !seenIds.contains(place.place_id) else { return false }
            seenIds.insert(place.place_id)
            return true
        }
        placeListPlaces[listId] = uniquePlaces
    }

    /// Appends places for a list with deduplication.
    func appendPlacesForList(listId: String, newPlaces: [LightweightPlace]) {
        var existingPlaces = placeListPlaces[listId] ?? []
        let existingIds = Set(existingPlaces.map { $0.place_id })
        let uniqueNewPlaces = newPlaces.filter { !existingIds.contains($0.place_id) }
        existingPlaces.append(contentsOf: uniqueNewPlaces)
        placeListPlaces[listId] = existingPlaces
    }

    /// Inserts a list at the beginning (for deep link scenarios).
    func insertListAtBeginning(_ list: LightweightPlaceList) {
        guard !userLists.contains(where: { $0.list_id == list.list_id }) else { return }
        userLists.insert(list, at: 0)
    }

    /// Resets all data.
    func resetAllData() {
        userLists = []
        placeListPlaces = [:]
        hasMoreLists = true
        currentListPage = 1
    }
}
