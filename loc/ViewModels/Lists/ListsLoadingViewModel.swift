//
//  ListsLoadingViewModel.swift
//  loc
//
//  Child ViewModel for list fetching and pagination.
//

import SwiftUI
import CoreLocation

/// Manages list fetching and pagination operations.
@MainActor
class ListsLoadingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Loading initial lists.
    @Published var isLoadingInitialLists: Bool = false

    /// Loading more lists (pagination).
    @Published var isLoadingMorePlaceLists: Bool = false

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?
    private weak var locationManager: LocationManager?

    // MARK: - ViewModel References

    private weak var dataViewModel: ListsDataViewModel?
    private weak var searchViewModel: ListsSearchViewModel?

    // MARK: - Callbacks

    /// Called when placeSavers dictionary needs updating.
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)?

    // MARK: - Initialization

    /// Initializes the loading view model with required dependencies.
    init(userService: UserService, userSession: UserSession, locationManager: LocationManager, dataViewModel: ListsDataViewModel) {
        self.userService = userService
        self.userSession = userSession
        self.locationManager = locationManager
        self.dataViewModel = dataViewModel
    }

    /// Sets the search view model reference (called after init to avoid circular dependency).
    func setSearchViewModel(_ searchVM: ListsSearchViewModel) {
        self.searchViewModel = searchVM
    }

    // MARK: - List Loading (Primary Data Flow)

    /// Loads the initial page of lists with proximity sorting and shared lists.
    func loadInitialLists() async {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }

        isLoadingInitialLists = true
        defer { isLoadingInitialLists = false }

        let pageSize = 12 // Covers full screen in 2-column grid without immediate pagination
        let userLocation = locationManager?.currentLocation?.coordinate

        // Fetch all list metadata (for instant search) in parallel with paginated lists
        async let allMetaTask: [LightweightPlaceList] = fetchAllListMetadata(userId: userId)

        // Fetch owned lists - use proximity sorting if location available
        var ownedLists: [LightweightPlaceList] = []

        if let location = userLocation {
            do {
                ownedLists = try await userService.fetchPlaceListsByProximity(
                    userId: userId,
                    userLatitude: location.latitude,
                    userLongitude: location.longitude,
                    page: 1,
                    pageSize: pageSize
                )
            } catch {
                print("❌ [ListsLoadingViewModel] Error fetching owned lists with proximity: \(error)")
                ownedLists = await fetchListsWithoutLocation(userId: userId, pageSize: pageSize)
            }
        } else {
            print("⚠️ [ListsLoadingViewModel] No user location available - loading lists without proximity sorting")
            ownedLists = await fetchListsWithoutLocation(userId: userId, pageSize: pageSize)
        }

        // Store all metadata cache (for instant search)
        let allMeta = await allMetaTask
        dataVM.allListsCache = allMeta

        // Fetch shared and collaborative lists in parallel
        var sharedLists: [SharedListInfo] = []
        var collaborativeOwnedLists: [CollaborativeOwnedList] = []

        do {
            sharedLists = try await CollaborationService.shared.fetchSharedLists(userId: userId)
        } catch {
            print("❌ [ListsLoadingViewModel] Error fetching shared lists: \(error)")
        }

        do {
            collaborativeOwnedLists = try await CollaborationService.shared.fetchCollaborativeOwnedLists(userId: userId)
        } catch {
            print("❌ [ListsLoadingViewModel] Error fetching collaborative owned lists: \(error)")
        }

        // Convert collaborative lists to LightweightPlaceList format
        let sharedAsLightweight = sharedLists.map { $0.toLightweightPlaceList() }
        let collaborativeOwnedAsLightweight = collaborativeOwnedLists.map { $0.toLightweightPlaceList() }

        // Get IDs of lists already in owned lists (to avoid duplicates)
        let ownedListIds = Set(ownedLists.map { $0.list_id })

        // Filter out collaborative owned lists that are already in paginated owned lists
        let additionalCollaborativeLists = collaborativeOwnedAsLightweight.filter {
            !ownedListIds.contains($0.list_id)
        }

        // Merge: owned (paginated) + collaborative owned (not in page 1) + shared with me
        let allLists = ownedLists + additionalCollaborativeLists + sharedAsLightweight

        // Only overwrite displayed lists if user hasn't started searching
        let isSearchActive = !(searchViewModel?.listSearchText.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        if !isSearchActive {
            dataVM.lightweightPlaceLists = allLists
        }

        dataVM.placeListsCurrentPage = 1
        dataVM.hasMorePlaceLists = ownedLists.count >= pageSize
        dataVM.initializePlaceCountsFromMetadata(for: allLists)

        // Load places only for lists without preview photos (shared/collaborative lists)
        // Owned lists already have preview_photos embedded in the RPC response
        let listsNeedingPlaces = allLists.filter { ($0.preview_photos ?? []).isEmpty && $0.place_count > 0 }
        if !listsNeedingPlaces.isEmpty {
            await loadPlacesForLists(listsNeedingPlaces)
        }
    }

    /// Loads more lists with pagination.
    func loadMoreLists() async {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }
        guard !isLoadingMorePlaceLists else { return }
        guard dataVM.hasMorePlaceLists else { return }
        guard let location = locationManager?.currentLocation?.coordinate else { return }

        isLoadingMorePlaceLists = true
        defer { isLoadingMorePlaceLists = false }

        let nextPage = dataVM.placeListsCurrentPage + 1
        let pageSize = 12

        do {
            let moreLists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: location.latitude,
                userLongitude: location.longitude,
                page: nextPage,
                pageSize: pageSize
            )

            dataVM.appendPlaceLists(moreLists, nextPage: nextPage, pageSize: pageSize)
            dataVM.initializePlaceCountsFromMetadata(for: moreLists)
        } catch {
            print("❌ [ListsLoadingViewModel] Error loading more place lists: \(error.localizedDescription)")
        }
    }

    /// Loads lists sorted by proximity to a specific place's coordinates.
    func loadListsByPlaceCoordinates(placeLatitude: Double, placeLongitude: Double) async {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }

        do {
            let lists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: placeLatitude,
                userLongitude: placeLongitude,
                page: 1,
                pageSize: 6
            )

            dataVM.lightweightPlaceLists = lists
            dataVM.placeListsCurrentPage = 1
            dataVM.hasMorePlaceLists = lists.count >= 6

            var updatedCounts: [String: Int] = [:]
            for list in lists {
                updatedCounts[list.list_id] = dataVM.lightweightPlaceListCounts[list.list_id] ?? list.place_count
            }
            dataVM.lightweightPlaceListCounts = updatedCounts

            await loadPlacesForLists(lists)
        } catch {
            print("❌ [ListsLoadingViewModel] Error loading place lists by coordinates: \(error.localizedDescription)")
        }
    }

    /// Fetches lightweight metadata for all user lists (powers instant local search).
    private func fetchAllListMetadata(userId: String) async -> [LightweightPlaceList] {
        do {
            return try await PlaceListService.shared.fetchAllListMetadata(userId: userId)
        } catch {
            print("❌ [ListsLoadingViewModel] Error fetching all list metadata: \(error)")
            return []
        }
    }

    /// Fetches lists without location-based sorting (fallback).
    private func fetchListsWithoutLocation(userId: String, pageSize: Int) async -> [LightweightPlaceList] {
        do {
            let lists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId,
                page: 1,
                pageSize: pageSize
            )
            return lists
        } catch {
            print("❌ [ListsLoadingViewModel] Error fetching lists without location: \(error)")
            return []
        }
    }

    // MARK: - Places Loading

    /// Loads places for multiple lists in parallel.
    func loadPlacesForLists(_ lists: [LightweightPlaceList]) async {
        guard let dataVM = dataViewModel else { return }

        var allPlaces: [String: [LightweightPlace]] = [:]

        await withTaskGroup(of: (String, [LightweightPlace]?).self) { group in
            for list in lists {
                group.addTask {
                    do {
                        let places = try await self.userService.fetchPlacesForPlaceList(
                            listId: list.list_id,
                            page: 1,
                            pageSize: 6
                        )
                        return (list.list_id, places)
                    } catch {
                        print("❌ [ListsLoadingViewModel] Error loading places for list \(list.list_id): \(error.localizedDescription)")
                        return (list.list_id, nil)
                    }
                }
            }

            for await (listId, places) in group {
                if let places = places {
                    allPlaces[listId] = places
                }
            }
        }

        // Prefetch external content metadata
        let allContentUrls = allPlaces.values.flatMap { $0.compactMap { $0.content_url } }.filter { !$0.isEmpty }
        if !allContentUrls.isEmpty {
            Task {
                await ExternalMetadataCache.shared.prefetchMetadata(for: Array(allContentUrls))
            }
        }

        // Update state (always run, even if no user session)
        for (listId, places) in allPlaces {
            dataVM.setPlacesForList(listId: listId, places: places)
        }

        // Notify about placeSavers updates (only if user session available)
        if let currentUserId = userSession?.currentUserId {
            for (_, places) in allPlaces {
                for place in places {
                    onPlaceSaversUpdate?(place.place_id, currentUserId, true)
                }
            }
        }

    }

    /// Loads the first page of places for a list if no places are cached yet.
    func loadPlacesForListIfNeeded(listId: String, fallbackCount: Int) async {
        guard let dataVM = dataViewModel else { return }
        if dataVM.lightweightPlaceListPlaces[listId] == nil {
            await loadPlacesForList(listId: listId)
        }
    }

    /// Loads places for a single list.
    func loadPlacesForList(listId: String) async {
        guard let dataVM = dataViewModel else { return }

        do {
            let places = try await userService.fetchPlacesForPlaceList(listId: listId, page: 1, pageSize: 6)

            dataVM.setPlacesForList(listId: listId, places: places)

            // Notify about placeSavers
            if let currentUserId = userSession?.currentUserId {
                for place in places {
                    onPlaceSaversUpdate?(place.place_id, currentUserId, true)
                }
            }
        } catch {
            print("❌ [ListsLoadingViewModel] Error loading places for list \(listId): \(error.localizedDescription)")
        }
    }

    /// Loads more places for a list with pagination.
    func loadMorePlacesForList(listId: String, page: Int, pageSize: Int = 6) async throws -> [LightweightPlace] {
        let places = try await userService.fetchPlacesForPlaceList(listId: listId, page: page, pageSize: pageSize)

        // Notify about placeSavers
        if let currentUserId = userSession?.currentUserId {
            for place in places {
                onPlaceSaversUpdate?(place.place_id, currentUserId, true)
            }
        }

        return places
    }

    /// Checks if more lists should be loaded based on scroll position.
    func shouldLoadMoreLists(currentItem: LightweightPlaceList, filteredLists: [LightweightPlaceList], isSearching: Bool) -> Bool {
        guard let dataVM = dataViewModel else { return false }
        guard !isSearching else { return false }
        guard !isLoadingMorePlaceLists && dataVM.hasMorePlaceLists else { return false }

        // Trigger when within last 5 items (~2.5 rows in 2-column grid)
        let threshold = max(0, filteredLists.count - 5)
        guard let currentIndex = filteredLists.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }

        return currentIndex >= threshold
    }

    // MARK: - Reset

    /// Resets loading states.
    func resetLoadingStates() {
        isLoadingInitialLists = false
        isLoadingMorePlaceLists = false
    }
}
