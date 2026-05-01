//
//  SavedListsViewModel.swift
//  loc
//
//  Manages saved lists — lists saved from other users' profiles.
//  Handles loading, pagination, save/unsave, and places for saved lists.
//

import Foundation
import CoreLocation

/// ViewModel for saved lists from other users' profiles.
@MainActor
class SavedListsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var savedLists: [LightweightPlaceList] = []
    @Published var savedListPlaces: [String: [LightweightPlace]] = [:]
    @Published var savedListIds: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreLists: Bool = true

    // MARK: - Callbacks

    /// Called after save/unsave to trigger map annotation reload.
    var onSavedListsChanged: (() -> Void)?

    // MARK: - Private State

    private var currentPage: Int = 1
    private let pageSize: Int = 6
    private var hasLoadedInitial: Bool = false

    // MARK: - Dependencies

    private let savedListService: SavedListService
    private let placeListService: PlaceListService
    private let userSession: UserSession
    private let locationManager: LocationManager

    // MARK: - Initialization

    init(userSession: UserSession, locationManager: LocationManager) {
        self.savedListService = SavedListService.shared
        self.placeListService = PlaceListService.shared
        self.userSession = userSession
        self.locationManager = locationManager
    }

    // MARK: - Loading

    /// Loads the first page of saved lists and caches all saved list IDs.
    func loadInitialLists() async {
        guard !hasLoadedInitial else { return }
        guard let userId = userSession.currentUserId else { return }

        isLoading = true
        hasLoadedInitial = true

        async let listsTask: Void = loadPage(userId: userId, page: 1)
        async let idsTask: Void = loadSavedListIds(userId: userId)

        _ = await (listsTask, idsTask)

        isLoading = false
    }

    /// Loads the next page of saved lists.
    func loadMoreLists() async {
        guard !isLoadingMore, hasMoreLists else { return }
        guard let userId = userSession.currentUserId else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1
        await loadPage(userId: userId, page: nextPage)
        isLoadingMore = false
    }

    /// Loads places for a specific saved list.
    func loadPlacesForList(listId: String) async {
        guard savedListPlaces[listId] == nil else { return }

        do {
            let places = try await placeListService.fetchPlacesInList(listId: listId)
            savedListPlaces[listId] = places
        } catch {
            print("❌ [SavedListsVM] Error loading places for list \(listId): \(error)")
        }
    }

    // MARK: - Save / Unsave

    /// Saves a list to the current user's profile.
    func saveList(listId: String) async -> Bool {
        guard let userId = userSession.currentUserId else { return false }

        do {
            try await savedListService.saveList(userId: userId, listId: listId)
            savedListIds.insert(listId)
            onSavedListsChanged?()
            return true
        } catch {
            print("❌ [SavedListsVM] Error saving list: \(error)")
            return false
        }
    }

    /// Unsaves a list from the current user's profile.
    func unsaveList(listId: String) async -> Bool {
        guard let userId = userSession.currentUserId else { return false }

        do {
            try await savedListService.unsaveList(userId: userId, listId: listId)
            savedListIds.remove(listId)
            savedLists.removeAll { $0.list_id == listId }
            savedListPlaces.removeValue(forKey: listId)
            onSavedListsChanged?()
            return true
        } catch {
            print("❌ [SavedListsVM] Error unsaving list: \(error)")
            return false
        }
    }

    /// Quick synchronous check if a list is saved (uses cached IDs).
    func isListSaved(listId: String) -> Bool {
        savedListIds.contains(listId)
    }

    // MARK: - Refresh

    /// Resets state and reloads saved lists from scratch.
    func refresh() async {
        hasLoadedInitial = false
        currentPage = 1
        hasMoreLists = true
        savedLists = []
        savedListPlaces = [:]
        await loadInitialLists()
    }

    // MARK: - Logout Cleanup

    /// Clears all saved list data on logout.
    func clearAllData() {
        savedLists = []
        savedListPlaces = [:]
        savedListIds = []
        isLoading = false
        isLoadingMore = false
        hasMoreLists = true
        currentPage = 1
        hasLoadedInitial = false
    }

    // MARK: - Private Helpers

    /// Loads a single page of saved lists.
    private func loadPage(userId: String, page: Int) async {
        guard let location = locationManager.currentLocation else { return }

        do {
            let lists = try await savedListService.fetchSavedLists(
                userId: userId,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                page: page,
                pageSize: pageSize
            )

            if page == 1 {
                savedLists = lists
            } else {
                savedLists.append(contentsOf: lists)
            }

            currentPage = page
            hasMoreLists = lists.count >= pageSize

            // Load places for fetched lists in parallel
            await withTaskGroup(of: Void.self) { group in
                for list in lists {
                    group.addTask { await self.loadPlacesForList(listId: list.list_id) }
                }
            }
        } catch {
            print("❌ [SavedListsVM] Error loading saved lists page \(page): \(error)")
        }
    }

    /// Fetches all saved list IDs for quick UI state checks.
    private func loadSavedListIds(userId: String) async {
        do {
            savedListIds = try await savedListService.fetchSavedListIds(userId: userId)
        } catch {
            print("❌ [SavedListsVM] Error loading saved list IDs: \(error)")
        }
    }
}
