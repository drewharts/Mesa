//
//  ExternalListPopupViewModel.swift
//  loc
//
//  Manages state and data loading for the external user's list popup.
//  Owns all list popup logic following MVVM + SRP principles.
//

import Foundation
import SwiftUI

@MainActor
class ExternalListPopupViewModel: ObservableObject {
    // MARK: - Published State

    @Published var lists: [LightweightPlaceList]
    @Published var listPlaces: [String: [LightweightPlace]]
    @Published var isLoadingPlaces: Bool = false
    @Published var currentListIndex: Int

    // MARK: - Dependencies

    private let userService: UserService

    // MARK: - Private State

    private var loadingListIds: Set<String> = []

    // MARK: - Computed Properties

    /// Returns the current list being displayed.
    var currentList: LightweightPlaceList {
        guard currentListIndex >= 0 && currentListIndex < lists.count else {
            return lists.first ?? LightweightPlaceList(
                list_id: "",
                name: "Unknown",
                is_public: true,
                image: nil,
                created_at: nil,
                updated_at: nil,
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
        }
        return lists[currentListIndex]
    }

    /// Returns places for the current list.
    var currentPlaces: [LightweightPlace] {
        return listPlaces[currentList.list_id] ?? []
    }

    /// Returns places for a list at a specific index.
    func places(forListAt index: Int) -> [LightweightPlace] {
        guard index >= 0 && index < lists.count else { return [] }
        let list = lists[index]
        return listPlaces[list.list_id] ?? []
    }

    /// Returns whether places are loading for a specific list index.
    func isLoading(forListAt index: Int) -> Bool {
        guard index >= 0 && index < lists.count else { return false }
        let list = lists[index]
        // Check if actively loading OR if it's the current list and global loading is true
        // (handles initial load state before loadPlacesForList adds to loadingListIds)
        let isActivelyLoading = loadingListIds.contains(list.list_id)
        let isCurrentListLoading = (index == currentListIndex && isLoadingPlaces)
        return isActivelyLoading || isCurrentListLoading
    }

    // MARK: - Initialization

    /// Initializes the ViewModel with lists and optional preloaded places.
    /// - Parameters:
    ///   - lists: The lists to display in the popup.
    ///   - initialListIndex: The index of the list to display initially.
    ///   - preloadedPlaces: Optional dictionary of preloaded places (from mapDisplayListPlaces).
    ///   - userService: The user service for fetching places (defaults to shared instance).
    init(
        lists: [LightweightPlaceList],
        initialListIndex: Int,
        preloadedPlaces: [String: [LightweightPlace]] = [:],
        userService: UserService? = nil
    ) {
        self.lists = lists
        self.currentListIndex = initialListIndex
        self.userService = userService ?? ServiceContainer.shared.userService

        // Only copy preloaded places that actually have data (non-empty arrays)
        // This prevents empty arrays from blocking the load
        var validPreloadedPlaces: [String: [LightweightPlace]] = [:]
        for (listId, places) in preloadedPlaces where !places.isEmpty {
            validPreloadedPlaces[listId] = places
        }
        self.listPlaces = validPreloadedPlaces

        // Check if current list needs loading - set loading state immediately
        let currentListId = lists.indices.contains(initialListIndex) ? lists[initialListIndex].list_id : ""
        if validPreloadedPlaces[currentListId] == nil {
            self.isLoadingPlaces = true
        }
    }

    // MARK: - Data Loading

    /// Loads places for the current list if not already loaded.
    func loadPlacesIfNeeded() async {
        let listId = currentList.list_id
        await loadPlacesForList(listId: listId)
    }

    /// Called when user swipes to a new list.
    func onListIndexChanged(_ newIndex: Int) {
        guard newIndex >= 0 && newIndex < lists.count else { return }
        currentListIndex = newIndex

        // Load places for the new list
        let listId = lists[newIndex].list_id
        Task { @MainActor in
            await loadPlacesForList(listId: listId)
        }
    }

    /// Loads places for a specific list if not already loaded or empty.
    private func loadPlacesForList(listId: String) async {
        // Skip if already loaded with data, or currently loading
        let existingPlaces = listPlaces[listId]
        guard (existingPlaces == nil || existingPlaces?.isEmpty == true) && !loadingListIds.contains(listId) else { return }

        loadingListIds.insert(listId)
        isLoadingPlaces = true

        defer {
            loadingListIds.remove(listId)
            // Only set isLoadingPlaces to false if no lists are loading
            if loadingListIds.isEmpty {
                isLoadingPlaces = false
            }
        }

        do {
            let places = try await userService.fetchPlacesForPlaceList(
                listId: listId,
                page: 1,
                pageSize: 20  // Load more initially for better UX
            )

            listPlaces[listId] = places
        } catch {
            print("❌ [ExternalListPopupVM] Error loading places for list \(listId): \(error)")
            // Set empty array to indicate we've attempted loading
            listPlaces[listId] = []
        }
    }

    /// Preloads places for adjacent lists (for smooth swiping).
    func preloadAdjacentLists() async {
        let indicesToPreload = [currentListIndex - 1, currentListIndex + 1]
            .filter { $0 >= 0 && $0 < lists.count }

        for index in indicesToPreload {
            let listId = lists[index].list_id
            await loadPlacesForList(listId: listId)
        }
    }
}
