//
//  ProfileListsViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for place lists management.
//

import SwiftUI
import CoreLocation

/// Manages place lists for the current user's profile.
@MainActor
class ProfileListsViewModel: ObservableObject {
    // MARK: - Published Properties - Lists

    /// User's place lists (legacy format)
    @Published var userLists: [PlaceList] = []

    /// Places in each list by list ID (legacy format)
    @Published var userListsPlaces: [String: [String]] = [:]

    /// Place counts per list (legacy format)
    @Published var placeListCounts: [UUID: Int] = [:]

    /// Lightweight place lists sorted by proximity
    @Published var lightweightPlaceLists: [LightweightPlaceList] = []

    /// Places in each lightweight list
    @Published var lightweightPlaceListPlaces: [String: [LightweightPlace]] = [:]

    /// Place counts for lightweight lists
    @Published var lightweightPlaceListCounts: [String: Int] = [:]

    // MARK: - Published Properties - Loading States

    /// Loading initial lists
    @Published var isLoadingInitialLists: Bool = false

    /// Loading more lists (pagination)
    @Published var isLoadingMorePlaceLists: Bool = false

    /// Has more lists to load
    @Published var hasMorePlaceLists: Bool = true

    /// Loaded list IDs (for lazy loading)
    @Published var loadedListIds: Set<UUID> = []

    /// Currently loading list IDs
    @Published var loadingListIds: Set<UUID> = []

    // MARK: - Published Properties - Filter & Search

    /// Show only shared/collaborative lists
    @Published var showOnlySharedLists: Bool = false

    /// Searching lists state
    @Published var isSearchingLists: Bool = false

    /// List search text
    @Published var listSearchText: String = ""

    // MARK: - Published Properties - Pagination

    /// Pagination state for places within each list
    @Published var listPlacePagination: [String: ListPlacePagination] = [:]

    /// Recently created list ID (for highlighting)
    @Published var recentlyCreatedListId: UUID?

    /// Total list count
    @Published var totalListCount: Int = 0

    // MARK: - Pagination State

    var placeListsCurrentPage: Int = 1

    // MARK: - Private State

    private var listCreationTime: Date?
    private let maxConcurrentListLoads = 2
    private var activeListLoadTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Dependencies

    private let userService: UserService
    private let placeService: PlaceService
    private weak var userSession: UserSession?
    private weak var locationManager: LocationManager?

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Called when placeSavers dictionary needs updating
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)?

    /// Called when annotation places need recalculating
    var onAnnotationPlacesRecalculate: (() -> Void)?

    /// Called when places dictionary needs updating
    var onPlacesUpdate: ((String, DetailPlace?) -> Void)?

    // MARK: - Initialization

    /// Initializes the lists view model with required dependencies.
    init(userService: UserService, placeService: PlaceService, userSession: UserSession, locationManager: LocationManager) {
        self.userService = userService
        self.placeService = placeService
        self.userSession = userSession
        self.locationManager = locationManager
    }

    // MARK: - Computed Properties

    /// Returns filtered lists based on current filter state.
    var filteredPlaceLists: [LightweightPlaceList] {
        if showOnlySharedLists {
            return lightweightPlaceLists.filter { $0.isCollaborative }
        }
        return lightweightPlaceLists
    }

    /// Count of collaborative lists.
    var collaborativeListCount: Int {
        lightweightPlaceLists.filter { $0.isCollaborative }.count
    }

    /// Whether there are any collaborative lists to filter.
    var hasSharedLists: Bool {
        collaborativeListCount > 0
    }

    /// Whether the Shared filter button should be interactive.
    var canInteractWithSharedFilter: Bool {
        !isLoadingInitialLists
    }

    // MARK: - List CRUD

    /// Creates a new place list.
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) async -> Result<PlaceList, Error> {
        guard let userId = userSession?.currentUserId else {
            return .failure(NSError(domain: "ProfileListsViewModel", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user session"]))
        }

        do {
            let createdList = try await SupabasePlaceService.shared.createNewList(
                userId: userId,
                name: name,
                city: city,
                emoji: emoji,
                image: image
            )

            // Update old format (for backward compatibility)
            userLists.append(createdList)
            setRecentlyCreatedList(createdList.id)

            // Add new list to top of lightweightPlaceLists for immediate UI update
            let lightweightList = LightweightPlaceList(
                list_id: createdList.id.uuidString,
                name: createdList.name,
                is_public: false,
                image: createdList.image,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date()),
                distance_meters: nil,
                place_count: 0,
                city: nil
            )
            lightweightPlaceLists.insert(lightweightList, at: 0)

            return .success(createdList)
        } catch {
            return .failure(error)
        }
    }

    /// Deletes a lightweight place list.
    func deleteLightweightList(_ list: LightweightPlaceList) async -> Result<Void, Error> {
        do {
            try await PlaceListService.shared.deleteList(listId: list.list_id)

            lightweightPlaceLists.removeAll { $0.list_id == list.list_id }
            lightweightPlaceListPlaces.removeValue(forKey: list.list_id)
            lightweightPlaceListCounts.removeValue(forKey: list.list_id)

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Removes a place list (legacy).
    func removePlaceList(placeList: PlaceList) {
        guard let userId = userSession?.currentUserId else { return }

        userLists.removeAll { $0.id == placeList.id }
        userListsPlaces.removeValue(forKey: placeList.id.uuidString)

        Task {
            try? await PlaceListService.shared.deleteList(listId: placeList.id.uuidString)
        }
    }

    // MARK: - Place Count

    /// Gets place count for a list.
    func placeCount(forListId listId: UUID) -> Int {
        return placeListCounts[listId] ?? 0
    }

    // MARK: - Recently Created List

    /// Sets the recently created list ID.
    func setRecentlyCreatedList(_ listId: UUID) {
        recentlyCreatedListId = listId
        listCreationTime = Date()
    }

    /// Clears the recently created list flag.
    func clearRecentlyCreatedList() {
        recentlyCreatedListId = nil
        listCreationTime = nil
    }

    /// Checks if a list is recently created (within last 60 seconds).
    func isListRecentlyCreated(_ listId: UUID) -> Bool {
        guard let createdId = recentlyCreatedListId,
              let creationTime = listCreationTime,
              createdId == listId else {
            return false
        }
        return Date().timeIntervalSince(creationTime) < 60
    }

    // MARK: - Reset

    /// Resets all lists data (used during logout).
    func resetAllData() {
        userLists.removeAll()
        userListsPlaces.removeAll()
        placeListCounts.removeAll()
        lightweightPlaceLists.removeAll()
        lightweightPlaceListPlaces.removeAll()
        lightweightPlaceListCounts.removeAll()
        isLoadingInitialLists = false
        isLoadingMorePlaceLists = false
        hasMorePlaceLists = true
        loadedListIds.removeAll()
        loadingListIds.removeAll()
        listPlacePagination.removeAll()
        activeListLoadTasks.values.forEach { $0.cancel() }
        activeListLoadTasks.removeAll()
        placeListsCurrentPage = 1
        showOnlySharedLists = false
        isSearchingLists = false
        listSearchText = ""
        recentlyCreatedListId = nil
        listCreationTime = nil
        totalListCount = 0
    }

    // MARK: - List Loading (Primary Data Flow)

    /// Loads the initial page of lists with proximity sorting and shared lists.
    func loadInitialLists() async {
        guard let userId = userSession?.currentUserId else { return }

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
                print("❌ [ProfileListsViewModel] Error fetching owned lists with proximity: \(error)")
                ownedLists = await fetchListsWithoutLocation(userId: userId, pageSize: pageSize)
            }
        } else {
            print("⚠️ [ProfileListsViewModel] No user location available - loading lists without proximity sorting")
            ownedLists = await fetchListsWithoutLocation(userId: userId, pageSize: pageSize)
        }

        // Fetch shared and collaborative lists in parallel
        var sharedLists: [SharedListInfo] = []
        var collaborativeOwnedLists: [CollaborativeOwnedList] = []

        do {
            sharedLists = try await CollaborationService.shared.fetchSharedLists(userId: userId)
        } catch {
            print("❌ [ProfileListsViewModel] Error fetching shared lists: \(error)")
        }

        do {
            collaborativeOwnedLists = try await CollaborationService.shared.fetchCollaborativeOwnedLists(userId: userId)
        } catch {
            print("❌ [ProfileListsViewModel] Error fetching collaborative owned lists: \(error)")
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

        print("📋 [ProfileListsViewModel] Loaded \(ownedLists.count) owned lists + \(additionalCollaborativeLists.count) additional collaborative owned + \(sharedLists.count) shared lists")

        // Update state
        lightweightPlaceLists = allLists
        placeListsCurrentPage = 1
        hasMorePlaceLists = ownedLists.count >= pageSize

        // Load places for each list
        if !allLists.isEmpty {
            await loadPlacesForLists(allLists)
        }
    }

    /// Loads more lists with pagination.
    func loadMoreLists() async {
        guard let userId = userSession?.currentUserId else { return }
        guard !isLoadingMorePlaceLists else {
            print("⚠️ [ProfileListsViewModel] Already loading more place lists, skipping")
            return
        }
        guard hasMorePlaceLists else {
            print("ℹ️ [ProfileListsViewModel] No more place lists to load")
            return
        }

        guard let location = locationManager?.currentLocation?.coordinate else {
            print("⚠️ [ProfileListsViewModel] No location available for loading more place lists")
            return
        }

        isLoadingMorePlaceLists = true
        defer { isLoadingMorePlaceLists = false }

        let nextPage = placeListsCurrentPage + 1
        let pageSize = 6

        do {
            let moreLists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: location.latitude,
                userLongitude: location.longitude,
                page: nextPage,
                pageSize: pageSize
            )

            appendPlaceLists(moreLists, nextPage: nextPage, pageSize: pageSize)

            if !moreLists.isEmpty {
                await loadPlacesForLists(moreLists)
            }
        } catch {
            print("❌ [ProfileListsViewModel] Error loading more place lists: \(error.localizedDescription)")
        }
    }

    /// Loads lists sorted by proximity to a specific place's coordinates.
    func loadListsByPlaceCoordinates(placeLatitude: Double, placeLongitude: Double) async {
        guard let userId = userSession?.currentUserId else { return }

        do {
            let lists = try await userService.fetchPlaceListsByProximity(
                userId: userId,
                userLatitude: placeLatitude,
                userLongitude: placeLongitude,
                page: 1,
                pageSize: 6
            )

            lightweightPlaceLists = lists
            placeListsCurrentPage = 1
            hasMorePlaceLists = lists.count >= 6

            var updatedCounts: [String: Int] = [:]
            for list in lists {
                updatedCounts[list.list_id] = lightweightPlaceListCounts[list.list_id] ?? list.place_count
            }
            lightweightPlaceListCounts = updatedCounts

            await loadPlacesForLists(lists)
        } catch {
            print("❌ [ProfileListsViewModel] Error loading place lists by coordinates: \(error.localizedDescription)")
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
            print("✅ [ProfileListsViewModel] Fetched \(lists.count) lists without proximity sorting")
            return lists
        } catch {
            print("❌ [ProfileListsViewModel] Error fetching lists without location: \(error)")
            return []
        }
    }

    // MARK: - Places Loading

    /// Loads places for multiple lists in parallel.
    func loadPlacesForLists(_ lists: [LightweightPlaceList]) async {
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
                        print("❌ [ProfileListsViewModel] Error loading places for list \(list.list_id): \(error.localizedDescription)")
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
            setPlacesForList(listId: listId, places: places)
        }

        // Notify about placeSavers updates (only if user session available)
        if let currentUserId = userSession?.currentUserId {
            for (_, places) in allPlaces {
                for place in places {
                    onPlaceSaversUpdate?(place.place_id, currentUserId, true)
                }
            }
        }

        print("📍 [ProfileListsViewModel] Updated places for \(allPlaces.count) lists")
    }

    /// Loads places for a single list.
    func loadPlacesForList(listId: String) async {
        do {
            let places = try await userService.fetchPlacesForPlaceList(listId: listId, page: 1, pageSize: 6)

            setPlacesForList(listId: listId, places: places)

            // Notify about placeSavers
            if let currentUserId = userSession?.currentUserId {
                for place in places {
                    onPlaceSaversUpdate?(place.place_id, currentUserId, true)
                }
            }
        } catch {
            print("❌ [ProfileListsViewModel] Error loading places for list \(listId): \(error.localizedDescription)")
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

    // MARK: - State Management

    /// Appends new place lists with deduplication.
    func appendPlaceLists(_ newLists: [LightweightPlaceList], nextPage: Int, pageSize: Int) {
        guard !newLists.isEmpty else {
            hasMorePlaceLists = false
            return
        }

        // Deduplication
        let existingIds = Set(lightweightPlaceLists.map { $0.list_id })
        let uniqueNewLists = newLists.filter { !existingIds.contains($0.list_id) }

        let duplicateCount = newLists.count - uniqueNewLists.count
        if duplicateCount > 0 {
            print("⚠️ [ProfileListsViewModel] Filtered \(duplicateCount) duplicate place lists")
        }

        if !uniqueNewLists.isEmpty {
            lightweightPlaceLists.append(contentsOf: uniqueNewLists)
            placeListsCurrentPage = nextPage
        }

        hasMorePlaceLists = newLists.count >= pageSize
    }

    /// Sets places for a list with deduplication.
    func setPlacesForList(listId: String, places: [LightweightPlace]) {
        var seenIds = Set<String>()
        let uniquePlaces = places.filter { place in
            if seenIds.contains(place.place_id) {
                return false
            }
            seenIds.insert(place.place_id)
            return true
        }

        lightweightPlaceListPlaces[listId] = uniquePlaces
        lightweightPlaceListCounts[listId] = uniquePlaces.count
    }

    /// Appends places for a list with deduplication.
    func appendPlacesForList(listId: String, newPlaces: [LightweightPlace]) {
        guard !newPlaces.isEmpty else { return }

        var existingPlaces = lightweightPlaceListPlaces[listId] ?? []
        let existingIds = Set(existingPlaces.map { $0.place_id })

        let uniqueNewPlaces = newPlaces.filter { !existingIds.contains($0.place_id) }

        if !uniqueNewPlaces.isEmpty {
            existingPlaces.append(contentsOf: uniqueNewPlaces)
            lightweightPlaceListPlaces[listId] = existingPlaces
        }
    }

    /// Checks if more lists should be loaded based on scroll position.
    func shouldLoadMoreLists(currentItem: LightweightPlaceList, filteredLists: [LightweightPlaceList], isSearching: Bool) -> Bool {
        guard !isSearching else { return false }
        guard !isLoadingMorePlaceLists && hasMorePlaceLists else { return false }

        let threshold = max(0, filteredLists.count - 3)
        guard let currentIndex = filteredLists.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }

        return currentIndex >= threshold
    }

    // MARK: - Search

    /// Performs server-side search across all user lists.
    func performListSearch() async {
        guard let userId = userSession?.currentUserId else { return }

        let searchTerm = listSearchText.trimmingCharacters(in: .whitespaces)
        guard !searchTerm.isEmpty else { return }

        do {
            let searchResults = try await PlaceListService.shared.searchListsByName(
                userId: userId,
                searchTerm: listSearchText
            )

            lightweightPlaceLists = searchResults

            for list in searchResults {
                if lightweightPlaceListCounts[list.list_id] == nil {
                    lightweightPlaceListCounts[list.list_id] = list.place_count
                }
            }

            // Load places for search results
            await withTaskGroup(of: (String, [LightweightPlace]?).self) { group in
                for list in searchResults {
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
                    if let places = places {
                        setPlacesForList(listId: listId, places: places)
                    }
                }
            }
        } catch {
            print("❌ [ProfileListsViewModel] Error searching lists: \(error)")
        }
    }

    /// Reloads lists when exiting search mode.
    func reloadListsAfterSearch() async {
        guard let userId = userSession?.currentUserId else { return }

        isLoadingInitialLists = true
        defer { isLoadingInitialLists = false }

        do {
            let location = locationManager?.currentLocation?.coordinate
            let lists: [LightweightPlaceList]

            if let location = location {
                lists = try await userService.fetchPlaceListsByProximity(
                    userId: userId,
                    userLatitude: location.latitude,
                    userLongitude: location.longitude,
                    page: 1,
                    pageSize: 6
                )
            } else {
                lists = try await userService.fetchPlaceListsWithoutLocation(
                    userId: userId,
                    page: 1,
                    pageSize: 6
                )
            }

            lightweightPlaceLists = lists
            placeListsCurrentPage = 1
            hasMorePlaceLists = lists.count >= 6

            await loadPlacesForLists(lists)
        } catch {
            print("❌ [ProfileListsViewModel] Error reloading lists after search: \(error)")
        }
    }
}
