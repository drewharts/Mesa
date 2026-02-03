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

    // MARK: - Data ViewModel Reference

    private weak var dataViewModel: ListsDataViewModel?

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

    // MARK: - List Loading (Primary Data Flow)

    /// Loads the initial page of lists with proximity sorting and shared lists.
    func loadInitialLists() async {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }

        isLoadingInitialLists = true
        defer { isLoadingInitialLists = false }

        let pageSize = 6
        let userLocation = locationManager?.currentLocation?.coordinate

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

        print("📋 [ListsLoadingViewModel] Loaded \(ownedLists.count) owned lists + \(additionalCollaborativeLists.count) additional collaborative owned + \(sharedLists.count) shared lists")

        // Update state
        dataVM.lightweightPlaceLists = allLists
        dataVM.placeListsCurrentPage = 1
        dataVM.hasMorePlaceLists = ownedLists.count >= pageSize

        // Load places for each list
        if !allLists.isEmpty {
            await loadPlacesForLists(allLists)
        }
    }

    /// Loads more lists with pagination.
    func loadMoreLists() async {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }
        guard !isLoadingMorePlaceLists else {
            print("⚠️ [ListsLoadingViewModel] Already loading more place lists, skipping")
            return
        }
        guard dataVM.hasMorePlaceLists else {
            print("ℹ️ [ListsLoadingViewModel] No more place lists to load")
            return
        }

        guard let location = locationManager?.currentLocation?.coordinate else {
            print("⚠️ [ListsLoadingViewModel] No location available for loading more place lists")
            return
        }

        isLoadingMorePlaceLists = true
        defer { isLoadingMorePlaceLists = false }

        let nextPage = dataVM.placeListsCurrentPage + 1
        let pageSize = 6

        do {
            let moreLists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: location.latitude,
                userLongitude: location.longitude,
                page: nextPage,
                pageSize: pageSize
            )

            dataVM.appendPlaceLists(moreLists, nextPage: nextPage, pageSize: pageSize)

            if !moreLists.isEmpty {
                await loadPlacesForLists(moreLists)
            }
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

    /// Fetches lists without location-based sorting (fallback).
    private func fetchListsWithoutLocation(userId: String, pageSize: Int) async -> [LightweightPlaceList] {
        do {
            let lists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId,
                page: 1,
                pageSize: pageSize
            )
            print("✅ [ListsLoadingViewModel] Fetched \(lists.count) lists without proximity sorting")
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

        // Prefetch TikTok metadata
        let allTiktokUrls = allPlaces.values.flatMap { $0.compactMap { $0.tiktok_url } }.filter { !$0.isEmpty }
        if !allTiktokUrls.isEmpty {
            Task {
                await TikTokMetadataCache.shared.prefetchMetadata(for: Array(allTiktokUrls))
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

        print("📍 [ListsLoadingViewModel] Updated places for \(allPlaces.count) lists")
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
