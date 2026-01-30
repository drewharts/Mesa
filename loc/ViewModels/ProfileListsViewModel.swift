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

    /// Called to get place coordinate for distance calculation
    var getPlaceCoordinate: ((String) -> CLLocationCoordinate2D?)?

    /// Called to get current user's info for collaborative list attribution
    var getUserInfo: (() -> (fullName: String?, profilePhotoURL: URL?)?)?

    /// Called to get placeSavers for a place
    var getPlaceSavers: ((String) -> [String]?)?

    /// Called to fetch place image
    var onFetchPlaceImage: ((String) -> Void)?

    /// Called to set parent's loading state
    var onSetLoading: ((Bool) -> Void)?

    /// Called to get current user ID
    var getCurrentUserId: (() -> String?)?

    /// Called to check if a place exists in the places dictionary
    var hasPlace: ((String) -> Bool)?

    // MARK: - Private State for Sorting

    private var hasPerformedInitialSort = false

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

    /// Creates a new place list with full state management.
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
            sortListsByDistance()
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

            // Refresh lightweight place lists to include the new list with proper sorting
            if let location = locationManager?.currentLocation?.coordinate {
                do {
                    let lists = try await SupabaseUserService.shared.fetchPlaceListsByProximity(
                        userId: userId,
                        userLatitude: location.latitude,
                        userLongitude: location.longitude,
                        page: 1,
                        pageSize: 6
                    )
                    // Merge: keep new list at top, then add others (avoiding duplicates)
                    var merged = [lightweightList]
                    merged.append(contentsOf: lists.filter { $0.list_id != lightweightList.list_id })
                    lightweightPlaceLists = merged
                    placeListsCurrentPage = 1
                    hasMorePlaceLists = lists.count >= 6
                } catch {
                    // Non-critical error - list was already added locally
                }
            }

            return .success(createdList)
        } catch {
            return .failure(error)
        }
    }

    /// Deletes a lightweight place list from database and removes from local state.
    func deleteLightweightList(_ list: LightweightPlaceList) async -> Result<Void, Error> {
        do {
            // Delete from database
            try await PlaceListService.shared.deleteList(listId: list.list_id)

            // Remove from local state
            lightweightPlaceLists.removeAll { $0.list_id == list.list_id }
            lightweightPlaceListPlaces.removeValue(forKey: list.list_id)
            lightweightPlaceListCounts.removeValue(forKey: list.list_id)

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Removes a place list (legacy PlaceList format).
    func removePlaceList(placeList: PlaceList) {
        guard let index = userLists.firstIndex(where: { $0.id == placeList.id }) else { return }
        guard let currentUserId = userSession?.currentUserId else { return }

        // Optimistic update: remove from local state
        userLists.remove(at: index)
        sortListsByDistance()

        // Persist deletion to database
        Task {
            do {
                try await PlaceListService.shared.deleteList(listId: placeList.id.uuidString)
            } catch {
                // Re-add the list if deletion failed
                await MainActor.run {
                    self.userLists.append(placeList)
                    self.sortListsByDistance()
                }
                print("❌ [ProfileListsViewModel] Failed to delete list: \(error)")
            }
        }
    }

    // MARK: - Place Count & Membership

    /// Gets place count for a list.
    func placeCount(forListId listId: UUID) -> Int {
        return placeListCounts[listId] ?? 0
    }

    /// Checks if a place is in a specific list.
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        let listIdString = listId.uuidString
        let places = userListsPlaces[listIdString] ?? []
        return places.contains(placeId)
    }

    /// Checks if a place is in any of the user's lists (uses SQL function).
    func isPlaceInAnyList(placeId: String) async -> Bool {
        guard let userId = userSession?.currentUserId else { return false }

        do {
            return try await PlaceListService.shared.isPlaceInAnyUserList(
                userId: userId,
                placeId: placeId
            )
        } catch {
            print("❌ [ProfileListsViewModel] Error checking place list membership: \(error)")
            return false
        }
    }

    // MARK: - Add/Remove Place from List

    /// Add a place to a lightweight list (current format).
    func addPlaceToLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        guard let userId = userSession?.currentUserId else { return }

        let placeId = place.id.uuidString

        // Create lightweight place object with added_by info for collaborative lists
        let userInfo = getUserInfo?()
        let lightweightPlace = LightweightPlace(
            place_id: placeId,
            name: place.name,
            latest_review_photo: place.photoUrls?.first,
            external_place_id: nil, // Not a TikTok external place
            tiktok_url: nil,
            added_by_user_id: userId,
            added_by_name: userInfo?.fullName,
            added_by_photo_url: userInfo?.profilePhotoURL?.absoluteString
        )

        var didInsert = false

        // Update local lightweightPlaceListPlaces
        // Insert at index 0 so new places appear first (matches DB sort_order behavior)
        if var existingPlaces = lightweightPlaceListPlaces[listId] {
            if !existingPlaces.contains(where: { $0.place_id == placeId }) {
                existingPlaces.insert(lightweightPlace, at: 0)  // Prepend, not append
                lightweightPlaceListPlaces[listId] = existingPlaces
                didInsert = true
            }
        } else {
            lightweightPlaceListPlaces[listId] = [lightweightPlace]
            didInsert = true
        }

        if didInsert {
            if let finalCount = updatedCount {
                // Caller owns state and has already done the math - just store it
                lightweightPlaceListCounts[listId] = finalCount
            } else {
                // Legacy path: we own the state, so we do the math
                let startingCount = lightweightPlaceListCounts[listId]
                    ?? lightweightPlaceLists.first(where: { $0.list_id == listId })?.place_count
                    ?? 0
                lightweightPlaceListCounts[listId] = startingCount + 1
            }
        }

        // Update places dictionary for immediate UI update
        onPlacesUpdate?(placeId, place)

        // Add current user as saver so places appear on map with profile picture
        let existingSavers = getPlaceSavers?(placeId)
        if existingSavers == nil || !(existingSavers?.contains(userId) ?? false) {
            onPlaceSaversUpdate?(placeId, userId, true)
        }

        // Recalculate map annotations to include the new place
        onAnnotationPlacesRecalculate?()

        // Persist to Supabase with added_by for collaborative list attribution
        Task {
            do {
                try await SupabaseUserService.shared.addPlaceToList(
                    listId: listId,
                    placeId: placeId,
                    addedBy: userId
                )
            } catch {
                print("❌ [ProfileListsViewModel] Failed to add place to list: \(error)")
            }
        }
    }

    /// Add a place to a list (old UUID-based format) - delegates to addPlaceToLightweightList.
    /// DEPRECATED: Use addPlaceToLightweightList directly for new code
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        let listIdString = listId.uuidString
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }) else { return }

        // Delegate to new implementation for core functionality
        addPlaceToLightweightList(listId: listIdString, place: place)

        // Legacy-specific: Update old PlaceList format
        let placeForList = place.toPlace()
        var places = userListsPlaces[listIdString] ?? []
        if !places.contains(place.id.uuidString) {
            places.append(place.id.uuidString)
            userListsPlaces[listIdString] = places
        }

        if !userLists[listIndex].places.contains(where: { $0.id == place.id }) {
            userLists[listIndex].places.append(placeForList)
            placeListCounts[listId] = userLists[listIndex].places.count
        }

        // Legacy-specific: Update average coordinates and pagination
        recalculateAverageCoordinates(for: listId)
        resetListPagination(listId: listId)
    }

    /// Remove a place from a lightweight list.
    func removePlaceFromLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        guard let userId = userSession?.currentUserId else {
            return
        }

        var didRemove = false

        // Update local lightweightPlaceListPlaces
        if var places = lightweightPlaceListPlaces[listId] {
            let originalCount = places.count
            places.removeAll { $0.place_id == place.id.uuidString }
            if places.count != originalCount {
                didRemove = true
            }
            lightweightPlaceListPlaces[listId] = places
        }

        if didRemove {
            if let finalCount = updatedCount {
                // Caller owns state and has already done the math - just store it
                lightweightPlaceListCounts[listId] = finalCount
            } else {
                // Legacy path: we own the state, so we do the math
                let startingCount = lightweightPlaceListCounts[listId]
                    ?? lightweightPlaceLists.first(where: { $0.list_id == listId })?.place_count
                    ?? 0
                lightweightPlaceListCounts[listId] = max(startingCount - 1, 0)
            }
        }

        // Remove current user as saver
        onPlaceSaversUpdate?(place.id.uuidString, userId, false)

        // Recalculate map annotations
        onAnnotationPlacesRecalculate?()

        // Persist to Supabase
        Task {
            do {
                try await SupabaseUserService.shared.removePlaceFromList(listId: listId, placeId: place.id.uuidString)
            } catch {
                print("❌ [ProfileListsViewModel] Failed to remove place from lightweight list: \(error)")
            }
        }
    }

    /// Remove a place from a list (old UUID-based format).
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        let listIdString = listId.uuidString
        guard
            var places = userListsPlaces[listIdString],
            let index = places.firstIndex(of: place.id.uuidString),
            let userId = userSession?.currentUserId,
            let list = userLists.first(where: { $0.id == listId })
        else {
            return
        }

        places.remove(at: index)
        userListsPlaces[listIdString] = places

        let placeForList = place.toPlace()

        placeService.removePlaceFromList(userId: userId, listId: list.id.uuidString, placeId: placeForList.id.uuidString) { error in
            if let error = error {
                print("❌ Error removing place from list: \(error)")
            }
        }

        // Recalculate average coordinates for this list
        recalculateAverageCoordinates(for: listId)

        // Reset pagination to reflect the removed place
        resetListPagination(listId: listId)

        // Skip sorting for individual place removals to avoid frequent re-sorting
    }

    /// Reset pagination for a list (call when places are added/removed).
    func resetListPagination(listId: UUID) {
        let listIdString = listId.uuidString
        listPlacePagination.removeValue(forKey: listIdString)

        // Re-initialize pagination if the list has places
        if let placeIds = userListsPlaces[listIdString], !placeIds.isEmpty {
            initializeListPagination(listId: listId)
        }
    }

    /// Initialize pagination state for a list.
    private func initializeListPagination(listId: UUID) {
        let listIdString = listId.uuidString
        guard let allPlaceIds = userListsPlaces[listIdString], !allPlaceIds.isEmpty else {
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
                    print("❌ [ProfileListsViewModel] loadNextPageForList: Failed to load place \(placeId): \(error.localizedDescription)")
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

    // MARK: - List Sorting by Distance

    /// Sorts userLists by their distance from the user's current location (closest first).
    func sortListsByDistance() {
        guard locationManager?.currentLocation != nil else {
            return
        }

        userLists.sort { list1, list2 in
            let distance1 = calculateDistanceToList(list1)
            let distance2 = calculateDistanceToList(list2)

            if distance1 != Double.infinity && distance2 != Double.infinity {
                return distance1 < distance2
            } else if distance1 != Double.infinity {
                return true
            } else if distance2 != Double.infinity {
                return false
            } else {
                return list1.name < list2.name
            }
        }

        hasPerformedInitialSort = true
    }

    /// Whether the initial sort has been performed.
    var hasCompletedInitialSort: Bool {
        hasPerformedInitialSort
    }

    /// Calculates the distance from the user's current location to a list.
    private func calculateDistanceToList(_ list: PlaceList) -> Double {
        guard let currentLocation = locationManager?.currentLocation else {
            return Double.infinity
        }

        // Use pre-calculated average coordinates if available
        if let averageCoordinate = list.averageCoordinate {
            let listLocation = CLLocation(
                latitude: averageCoordinate.latitude,
                longitude: averageCoordinate.longitude
            )
            return currentLocation.distance(from: listLocation)
        }

        // Fallback to calculating average distance from individual places
        let listPlaceIds = userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { return Double.infinity }

        var totalDistance: Double = 0
        var validPlaceCount: Int = 0

        for placeId in listPlaceIds {
            if let coordinate = getPlaceCoordinate?(placeId) {
                let placeLocation = CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                totalDistance += currentLocation.distance(from: placeLocation)
                validPlaceCount += 1
            }
        }

        return validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
    }

    /// Recalculates the average coordinates for a specific list.
    func recalculateAverageCoordinates(for listId: UUID) {
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }),
              let placeIds = userListsPlaces[listId.uuidString] else {
            return
        }

        var totalLatitude: Double = 0
        var totalLongitude: Double = 0
        var validPlaceCount: Int = 0

        for placeId in placeIds {
            if let coordinate = getPlaceCoordinate?(placeId) {
                totalLatitude += coordinate.latitude
                totalLongitude += coordinate.longitude
                validPlaceCount += 1
            }
        }

        if validPlaceCount > 0 {
            let averageLatitude = totalLatitude / Double(validPlaceCount)
            let averageLongitude = totalLongitude / Double(validPlaceCount)

            userLists[listIndex].averageCoordinate = CLLocationCoordinate2D(
                latitude: averageLatitude,
                longitude: averageLongitude
            )
            userLists[listIndex].lastCoordinateUpdate = Date()

            // Persist to backend
            if let userId = userSession?.currentUserId {
                Task {
                    await updateListAverageCoordinates(
                        userId: userId,
                        listId: listId,
                        averageCoordinate: userLists[listIndex].averageCoordinate!
                    )
                }
            }
        } else {
            userLists[listIndex].averageCoordinate = nil
            userLists[listIndex].lastCoordinateUpdate = Date()
        }
    }

    /// Updates the average coordinates in Supabase.
    private func updateListAverageCoordinates(userId: String, listId: UUID, averageCoordinate: CLLocationCoordinate2D) async {
        // TODO: Implement with Supabase
        print("⚠️ updateListAverageCoordinates not yet implemented for Supabase")
    }

    // MARK: - Reset

    /// Resets all lists data (used during logout).
    func resetAllData() {
        hasPerformedInitialSort = false
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

    // MARK: - Legacy List Loading (DetailPlace-based)

    /// Ensures lists are loaded with DetailPlace data for legacy views.
    func ensureListsLoaded() {
        guard let userId = getCurrentUserId?() else {
            return
        }

        // Check if we need to load places for the first 3 lists
        let firstThreeLists = Array(userLists.prefix(3))
        let needsPlaceLoading = firstThreeLists.contains { list in
            userListsPlaces[list.id.uuidString]?.isEmpty != false
        }

        if !needsPlaceLoading {
            onSetLoading?(false)
            return
        }

        // Indicate loading state so UI can show a spinner
        onSetLoading?(true)

        Task {
            do {
                // Use the existing lists (already loaded by DataManager)
                let lists = self.userLists

                // Load places and counts for the first 3 visible lists
                let firstThreeListIds = Array(lists.prefix(3).map { $0.id.uuidString })

                if !firstThreeListIds.isEmpty {
                    // Fetch places for first 3 lists (6 places each)
                    let placesForLists = try await placeService.fetchPlacesForLists(listIds: firstThreeListIds, maxPlacesPerList: 6)

                    // Fetch place counts for all lists
                    let placeCounts = try await placeService.getPlaceCountsForLists(listIds: lists.map { $0.id.uuidString })

                    await MainActor.run {
                        // Update places for first 3 lists
                        for (listId, places) in placesForLists {
                            let placeIds = places.map { $0.id.uuidString }
                            self.userListsPlaces[listId] = placeIds

                            // Store places in detailPlaceViewModel for immediate access
                            for place in places {
                                self.onPlacesUpdate?(place.id.uuidString, place)
                            }

                            // Load images for these places
                            for place in places {
                                self.onFetchPlaceImage?(place.id.uuidString)
                            }

                            // Mark as loaded
                            if let uuid = UUID(uuidString: listId) {
                                self.loadedListIds.insert(uuid)
                            }
                        }

                        // Store place counts for all lists (for display)
                        for (listId, count) in placeCounts {
                            if let uuid = UUID(uuidString: listId) {
                                self.placeListCounts[uuid] = count
                            }
                        }

                        self.onSetLoading?(false)
                    }
                } else {
                    await MainActor.run {
                        self.onSetLoading?(false)
                    }
                }

            } catch {
                print("❌ [ProfileListsViewModel] ensureListsLoaded: Error loading places for lists: \(error.localizedDescription)")
                await MainActor.run {
                    self.onSetLoading?(false)
                }
            }
        }
    }

    /// Loads list data if needed for a specific list.
    func loadListDataIfNeeded(listId: UUID) {
        guard !loadedListIds.contains(listId) && !loadingListIds.contains(listId),
              let userId = getCurrentUserId?() else {
            return
        }

        // Check if we're at the concurrency limit
        if activeListLoadTasks.count >= maxConcurrentListLoads {
            // Queue the task for later execution
            let task = Task {
                // Wait for a slot to become available
                while activeListLoadTasks.count >= maxConcurrentListLoads {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    if Task.isCancelled { return }
                }
                await self.performListLoad(listId: listId, userId: userId)
            }
            activeListLoadTasks[listId] = task
            return
        }

        // Execute immediately if under the limit
        let task = Task {
            await self.performListLoad(listId: listId, userId: userId)
        }
        activeListLoadTasks[listId] = task
    }

    /// Performs the actual list load operation.
    private func performListLoad(listId: UUID, userId: String) async {
        // Check if places are already loaded (e.g., from preloading)
        let alreadyLoaded = await MainActor.run {
            let listIdString = listId.uuidString
            let hasPlaceIds = userListsPlaces[listIdString]?.isEmpty == false
            let hasDetailPlaces = userListsPlaces[listIdString]?.allSatisfy { placeId in
                hasPlace?(placeId) ?? false
            } ?? false
            return hasPlaceIds && hasDetailPlaces
        }

        if alreadyLoaded {
            await MainActor.run {
                self.loadedListIds.insert(listId)
                self.initializeListPaginationIfNeeded(listId: listId)
            }
            return
        }

        _ = await MainActor.run {
            self.loadingListIds.insert(listId)
        }

        // Use the optimized method to load places for this list
        do {
            let placesForLists = try await placeService.fetchPlacesForLists(
                listIds: [listId.uuidString],
                maxPlacesPerList: 50 // Load more places when list is opened
            )

            if let places = placesForLists[listId.uuidString] {
                await MainActor.run {
                    let placeIds = places.map { $0.id.uuidString }
                    self.userListsPlaces[listId.uuidString] = placeIds

                    // Store places in detailPlaceViewModel for immediate access
                    for place in places {
                        self.onPlacesUpdate?(place.id.uuidString, place)
                    }

                    // Load images for these places
                    for place in places {
                        self.onFetchPlaceImage?(place.id.uuidString)
                    }

                    self.loadedListIds.insert(listId)
                    self.loadingListIds.remove(listId)
                    self.activeListLoadTasks.removeValue(forKey: listId)

                    // Initialize pagination for this list
                    self.initializeListPaginationIfNeeded(listId: listId)
                }
            }
        } catch {
            print("❌ [ProfileListsViewModel] performListLoad: Error loading places for list \(listId): \(error)")
            await MainActor.run {
                self.loadingListIds.remove(listId)
                self.activeListLoadTasks.removeValue(forKey: listId)
            }
        }
    }

    /// Load more lists when user scrolls (lazy loading).
    func loadMoreListsIfNeeded() {
        // Find the next 3 lists that haven't been loaded yet
        let unloadedLists = userLists.filter { !loadedListIds.contains($0.id) && !loadingListIds.contains($0.id) }
        let nextThreeLists = Array(unloadedLists.prefix(3))

        guard !nextThreeLists.isEmpty else { return }

        let listIds = nextThreeLists.map { $0.id.uuidString }

        Task {
            do {
                // Mark as loading
                await MainActor.run {
                    for list in nextThreeLists {
                        self.loadingListIds.insert(list.id)
                    }
                }

                // Fetch places for these lists
                let placesForLists = try await placeService.fetchPlacesForLists(listIds: listIds, maxPlacesPerList: 6)

                await MainActor.run {
                    // Update places for these lists
                    for (listId, places) in placesForLists {
                        let placeIds = places.map { $0.id.uuidString }
                        self.userListsPlaces[listId] = placeIds

                        // Store places in detailPlaceViewModel for immediate access
                        for place in places {
                            self.onPlacesUpdate?(place.id.uuidString, place)
                        }

                        // Load images for these places
                        for place in places {
                            self.onFetchPlaceImage?(place.id.uuidString)
                        }

                        // Mark as loaded
                        if let uuid = UUID(uuidString: listId) {
                            self.loadedListIds.insert(uuid)
                            self.loadingListIds.remove(uuid)
                        }
                    }
                }
            } catch {
                print("❌ [ProfileListsViewModel] loadMoreListsIfNeeded: Error loading more lists: \(error)")
                await MainActor.run {
                    for list in nextThreeLists {
                        self.loadingListIds.remove(list.id)
                    }
                }
            }
        }
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
