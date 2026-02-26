//
//  ExternalListsLoadingViewModel.swift
//  loc
//
//  Child ViewModel for external profile list fetching and pagination.
//  Uses TaskGroup for parallel place loading and proximity sorting.
//

import SwiftUI
import CoreLocation

/// Manages list fetching and pagination for external user profiles.
@MainActor
class ExternalListsLoadingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Loading initial lists.
    @Published var isLoadingInitialLists: Bool = false

    /// Loading more lists (pagination).
    @Published var isLoadingMoreLists: Bool = false

    // MARK: - Dependencies

    private let userService: UserService
    private let userId: String
    private weak var locationManager: LocationManager?
    private weak var dataViewModel: ExternalListsDataViewModel?

    // MARK: - Tracking Sets

    private var loadedListIds: Set<String> = []
    private var loadingListIds: Set<String> = []

    // MARK: - Initialization

    /// Initializes the loading view model with required dependencies.
    init(userId: String, userService: UserService, dataViewModel: ExternalListsDataViewModel) {
        self.userId = userId
        self.userService = userService
        self.dataViewModel = dataViewModel
    }

    /// Sets the location manager for proximity-based sorting.
    func setLocationManager(_ locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    // MARK: - Initial Loading

    /// Loads initial lists sorted by proximity to user's current location.
    func loadInitialLists() async {
        guard let dataVM = dataViewModel else { return }

        isLoadingInitialLists = true
        defer { isLoadingInitialLists = false }

        let userLocation = locationManager?.currentLocation?.coordinate
        var lists: [LightweightPlaceList] = []

        // Use proximity sorting if location available, otherwise fallback
        if let location = userLocation {
            lists = await fetchListsWithProximity(
                latitude: location.latitude,
                longitude: location.longitude,
                page: 1,
                pageSize: dataVM.listsPerPage
            )
        } else {
            print("⚠️ [ExternalListsLoadingViewModel] No user location - loading lists without proximity sorting")
            lists = await fetchListsWithoutLocation(page: 1, pageSize: dataVM.listsPerPage)
        }

        dataVM.userLists = lists
        dataVM.currentListPage = 1
        dataVM.hasMoreLists = lists.count >= dataVM.listsPerPage

        // Load places for ALL initial lists in parallel
        if !lists.isEmpty {
            await loadPlacesForLists(lists)
        }
    }

    /// Fetches lists sorted by proximity to given coordinates.
    private func fetchListsWithProximity(latitude: Double, longitude: Double, page: Int, pageSize: Int) async -> [LightweightPlaceList] {
        do {
            let lists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: latitude,
                userLongitude: longitude,
                page: page,
                pageSize: pageSize
            )
            return lists
        } catch {
            print("❌ [ExternalListsLoadingViewModel] Error fetching lists with proximity: \(error)")
            // Fallback to non-proximity fetch
            return await fetchListsWithoutLocation(page: page, pageSize: pageSize)
        }
    }

    /// Fetches lists without location-based sorting (fallback).
    private func fetchListsWithoutLocation(page: Int, pageSize: Int) async -> [LightweightPlaceList] {
        do {
            let lists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId,
                page: page,
                pageSize: pageSize
            )
            return lists
        } catch {
            print("❌ [ExternalListsLoadingViewModel] Error fetching lists without location: \(error)")
            return []
        }
    }

    // MARK: - Pagination

    /// Loads more lists with pagination using proximity sorting when available.
    func loadMoreLists() async {
        guard let dataVM = dataViewModel else { return }
        guard !isLoadingMoreLists else { return }
        guard dataVM.hasMoreLists else { return }

        isLoadingMoreLists = true
        defer { isLoadingMoreLists = false }

        let nextPage = dataVM.currentListPage + 1
        let userLocation = locationManager?.currentLocation?.coordinate
        var newLists: [LightweightPlaceList] = []

        // Use proximity sorting if location available
        if let location = userLocation {
            newLists = await fetchListsWithProximity(
                latitude: location.latitude,
                longitude: location.longitude,
                page: nextPage,
                pageSize: dataVM.listsPerPage
            )
        } else {
            newLists = await fetchListsWithoutLocation(page: nextPage, pageSize: dataVM.listsPerPage)
        }

        dataVM.appendLists(newLists, nextPage: nextPage)

        // Load places for new lists
        if !newLists.isEmpty {
            await loadPlacesForLists(newLists)
        }
    }

    // MARK: - Places Loading

    /// Loads places for multiple lists in parallel using TaskGroup.
    func loadPlacesForLists(_ lists: [LightweightPlaceList]) async {
        guard let dataVM = dataViewModel else { return }

        await withTaskGroup(of: (String, [LightweightPlace]?).self) { group in
            for list in lists {
                guard !loadedListIds.contains(list.list_id),
                      !loadingListIds.contains(list.list_id) else { continue }

                loadingListIds.insert(list.list_id)

                group.addTask {
                    do {
                        let places = try await self.userService.fetchPlacesForPlaceList(
                            listId: list.list_id,
                            page: 1,
                            pageSize: 6
                        )
                        return (list.list_id, places)
                    } catch {
                        return (list.list_id, nil)
                    }
                }
            }

            for await (listId, places) in group {
                loadingListIds.remove(listId)
                if let places = places {
                    loadedListIds.insert(listId)
                    dataVM.setPlacesForList(listId: listId, places: places)
                }
            }
        }
    }

    /// Loads places for a single list.
    func loadPlacesForList(_ list: LightweightPlaceList) async {
        guard let dataVM = dataViewModel else { return }
        guard !loadedListIds.contains(list.list_id),
              !loadingListIds.contains(list.list_id) else { return }

        loadingListIds.insert(list.list_id)
        defer { loadingListIds.remove(list.list_id) }

        do {
            let places = try await userService.fetchPlacesForPlaceList(
                listId: list.list_id,
                page: 1,
                pageSize: 6
            )
            loadedListIds.insert(list.list_id)
            dataVM.setPlacesForList(listId: list.list_id, places: places)
        } catch {
            print("❌ [ExternalListsLoadingViewModel] Error loading places for list: \(error)")
            dataVM.setPlacesForList(listId: list.list_id, places: [])
        }
    }

    /// Loads more places for a list with pagination.
    func loadMorePlacesForList(listId: String, page: Int) async -> [LightweightPlace] {
        guard let dataVM = dataViewModel else { return [] }

        do {
            let places = try await userService.fetchPlacesForPlaceList(
                listId: listId,
                page: page,
                pageSize: 6
            )
            dataVM.appendPlacesForList(listId: listId, newPlaces: places)
            return places
        } catch {
            print("❌ [ExternalListsLoadingViewModel] Error loading more places: \(error)")
            return []
        }
    }

    // MARK: - Pagination Helpers

    /// Checks if more lists should be loaded (trigger at last 5 items).
    func shouldLoadMoreLists(currentItem: LightweightPlaceList, allLists: [LightweightPlaceList]) -> Bool {
        guard let dataVM = dataViewModel else { return false }
        guard !isLoadingMoreLists && dataVM.hasMoreLists else { return false }

        // Match own profile: trigger at last 5 items
        let threshold = max(0, allLists.count - 5)
        guard let currentIndex = allLists.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }

        return currentIndex >= threshold
    }

    // MARK: - Reset

    /// Resets loading state.
    func resetLoadingState() {
        isLoadingInitialLists = false
        isLoadingMoreLists = false
        loadedListIds.removeAll()
        loadingListIds.removeAll()
    }
}
