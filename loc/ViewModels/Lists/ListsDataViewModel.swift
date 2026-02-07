//
//  ListsDataViewModel.swift
//  loc
//
//  Child ViewModel for core list data storage and CRUD operations.
//

import SwiftUI
import CoreLocation

/// Manages core list data storage and CRUD operations.
@MainActor
class ListsDataViewModel: ObservableObject {
    // MARK: - Published Properties - Legacy Format

    /// User's place lists (legacy format).
    @Published var userLists: [PlaceList] = []

    /// Places in each list by list ID (legacy format).
    @Published var userListsPlaces: [String: [String]] = [:]

    /// Place counts per list (legacy format).
    @Published var placeListCounts: [UUID: Int] = [:]

    // MARK: - Published Properties - Lightweight Format

    /// Lightweight place lists sorted by proximity.
    @Published var lightweightPlaceLists: [LightweightPlaceList] = []

    /// Places in each lightweight list.
    @Published var lightweightPlaceListPlaces: [String: [LightweightPlace]] = [:]

    /// Place counts for lightweight lists.
    @Published var lightweightPlaceListCounts: [String: Int] = [:]

    // MARK: - Published Properties - State

    /// Recently created list ID (for highlighting).
    @Published var recentlyCreatedListId: UUID?

    /// Total list count.
    @Published var totalListCount: Int = 0

    // MARK: - Pagination State

    /// Current page for list pagination.
    var placeListsCurrentPage: Int = 1

    /// Has more lists to load.
    @Published var hasMorePlaceLists: Bool = true

    // MARK: - Private State

    private var listCreationTime: Date?

    // MARK: - Dependencies

    private weak var userSession: UserSession?
    private weak var locationManager: LocationManager?

    // MARK: - Callbacks

    /// Called to trigger distance sorting after list creation.
    var onSortListsByDistance: (() -> Void)?

    // MARK: - Initialization

    /// Initializes the data view model with required dependencies.
    init(userSession: UserSession, locationManager: LocationManager) {
        self.userSession = userSession
        self.locationManager = locationManager
    }

    // MARK: - List CRUD

    /// Creates a new place list with full state management.
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) async -> Result<PlaceList, Error> {
        guard let userId = userSession?.currentUserId else {
            return .failure(NSError(domain: "ListsDataViewModel", code: -1,
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
            onSortListsByDistance?()
            setRecentlyCreatedList(createdList.id)

            // Add new list to top of lightweightPlaceLists for immediate UI update
            let lightweightList = LightweightPlaceList(
                list_id: createdList.id.uuidString,
                name: createdList.name,
                is_public: true,
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

        // Optimistic update: remove from local state
        userLists.remove(at: index)
        onSortListsByDistance?()

        // Persist deletion to database
        Task {
            do {
                try await PlaceListService.shared.deleteList(listId: placeList.id.uuidString)
            } catch {
                // Re-add the list if deletion failed
                await MainActor.run {
                    self.userLists.append(placeList)
                    self.onSortListsByDistance?()
                }
                print("❌ [ListsDataViewModel] Failed to delete list: \(error)")
            }
        }
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

    // MARK: - Reset

    /// Resets all lists data (used during logout).
    func resetAllData() {
        userLists.removeAll()
        userListsPlaces.removeAll()
        placeListCounts.removeAll()
        lightweightPlaceLists.removeAll()
        lightweightPlaceListPlaces.removeAll()
        lightweightPlaceListCounts.removeAll()
        hasMorePlaceLists = true
        placeListsCurrentPage = 1
        recentlyCreatedListId = nil
        listCreationTime = nil
        totalListCount = 0
    }
}
