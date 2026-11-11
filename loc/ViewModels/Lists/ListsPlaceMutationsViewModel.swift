//
//  ListsPlaceMutationsViewModel.swift
//  loc
//
//  Child ViewModel for adding/removing places from lists.
//

import SwiftUI
import CoreLocation

/// Manages adding and removing places from lists.
@MainActor
class ListsPlaceMutationsViewModel: ObservableObject {
    // MARK: - Dependencies

    private let placeService: PlaceService
    private weak var userSession: UserSession?

    // MARK: - ViewModel References

    private weak var dataViewModel: ListsDataViewModel?
    private weak var distanceSortingViewModel: ListsDistanceSortingViewModel?
    private weak var placePaginationViewModel: ListsPlacePaginationViewModel?

    // MARK: - Callbacks

    /// Called when placeSavers dictionary needs updating.
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)?

    /// Called when annotation places need recalculating.
    var onAnnotationPlacesRecalculate: (() -> Void)?

    /// Called when places dictionary needs updating.
    var onPlacesUpdate: ((String, DetailPlace?) -> Void)?

    /// Called to get current user's info for collaborative list attribution.
    var getUserInfo: (() -> (fullName: String?, profilePhotoURL: URL?)?)?

    /// Called to get placeSavers for a place.
    var getPlaceSavers: ((String) -> [String]?)?

    // MARK: - Initialization

    /// Initializes the mutations view model with required dependencies.
    init(placeService: PlaceService, userSession: UserSession, dataViewModel: ListsDataViewModel) {
        self.placeService = placeService
        self.userSession = userSession
        self.dataViewModel = dataViewModel
    }

    /// Sets the distance sorting view model reference.
    func setDistanceSortingViewModel(_ viewModel: ListsDistanceSortingViewModel) {
        self.distanceSortingViewModel = viewModel
    }

    /// Sets the place pagination view model reference.
    func setPlacePaginationViewModel(_ viewModel: ListsPlacePaginationViewModel) {
        self.placePaginationViewModel = viewModel
    }

    // MARK: - Place Count & Membership

    /// Gets place count for a list.
    func placeCount(forListId listId: UUID) -> Int {
        guard let dataVM = dataViewModel else { return 0 }
        return dataVM.placeListCounts[listId] ?? 0
    }

    /// Checks if a place is in a specific list.
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        guard let dataVM = dataViewModel else { return false }
        let listIdString = listId.uuidString
        let places = dataVM.userListsPlaces[listIdString] ?? []
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
            print("❌ [ListsPlaceMutationsViewModel] Error checking place list membership: \(error)")
            return false
        }
    }

    // MARK: - Add Place to List

    /// Errors from the add-to-list flow that happen before any network call.
    enum AddToListError: LocalizedError {
        case unavailable

        var errorDescription: String? { "Not signed in or lists not loaded" }
    }

    /// What an optimistic add changed locally, so it can be rolled back or re-keyed.
    private struct PendingAdd {
        let listId: String
        let place: DetailPlace
        let placeId: String
        let userId: String
        let lightweightPlace: LightweightPlace
        let didInsert: Bool
        let previousCount: Int?
        let addedSaver: Bool
    }

    /// Add a place to a lightweight list (current format).
    /// Updates the local cache immediately, persists in the background, and rolls the local
    /// change back if the save fails. Use `addPlaceToLightweightListAndWait` to learn the outcome.
    func addPlaceToLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        guard let pending = applyOptimisticAdd(listId: listId, place: place, updatedCount: updatedCount) else { return }
        Task { [weak self] in
            try? await self?.persistAdd(pending)
        }
    }

    /// Same as `addPlaceToLightweightList`, but suspends until the row is saved.
    /// Throws (after rolling back the local insert) if the save fails.
    func addPlaceToLightweightListAndWait(listId: String, place: DetailPlace, updatedCount: Int? = nil) async throws {
        guard let pending = applyOptimisticAdd(listId: listId, place: place, updatedCount: updatedCount) else {
            throw AddToListError.unavailable
        }
        try await persistAdd(pending)
    }

    /// Optimistically inserts the place into the local list cache. Returns nil if there is no
    /// signed-in user or data view model.
    private func applyOptimisticAdd(listId: String, place: DetailPlace, updatedCount: Int?) -> PendingAdd? {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return nil }

        let placeId = place.id.uuidString

        // Create lightweight place object with added_by info for collaborative lists
        let userInfo = getUserInfo?()
        let lightweightPlace = LightweightPlace(
            place_id: placeId,
            name: place.name,
            latest_review_photo: place.photoUrls?.first,
            external_place_id: nil,
            content_url: nil,
            added_by_user_id: userId,
            added_by_name: userInfo?.fullName,
            added_by_photo_url: userInfo?.profilePhotoURL?.absoluteString
        )

        let previousCount = dataVM.cachedCount(forListId: listId)

        // Update local lightweightPlaceListPlaces
        // Insert at index 0 so new places appear first (matches DB sort_order behavior)
        let result = ListPlaceOptimisticUpdate.applyingAdd(lightweightPlace, to: dataVM.places(forListId: listId))
        if result.didInsert {
            dataVM.storePlaces(result.places, forListId: listId)
            if let finalCount = updatedCount {
                dataVM.storeCount(finalCount, forListId: listId)
            } else {
                let metadata = dataVM.lightweightPlaceLists.first(where: {
                    ListPlaceCount.normalizedId($0.list_id) == ListPlaceCount.normalizedId(listId)
                })?.place_count
                let startingCount = previousCount ?? metadata ?? 0
                dataVM.storeCount(startingCount + 1, forListId: listId)
            }
        }

        // Update places dictionary for immediate UI update
        onPlacesUpdate?(placeId, place)

        // Add current user as saver so places appear on map with profile picture
        let existingSavers = getPlaceSavers?(placeId)
        let addedSaver = existingSavers == nil || !(existingSavers?.contains(userId) ?? false)
        if addedSaver {
            onPlaceSaversUpdate?(placeId, userId, true)
        }

        // Recalculate map annotations to include the new place
        onAnnotationPlacesRecalculate?()

        return PendingAdd(
            listId: listId,
            place: place,
            placeId: placeId,
            userId: userId,
            lightweightPlace: lightweightPlace,
            didInsert: result.didInsert,
            previousCount: previousCount,
            addedSaver: addedSaver
        )
    }

    /// Persists an optimistic add to Supabase with added_by for collaborative list attribution.
    /// On failure, undoes the local change and rethrows.
    private func persistAdd(_ pending: PendingAdd) async throws {
        do {
            let savedPlaceId = try await SupabaseUserService.shared.addPlaceToList(
                listId: pending.listId,
                placeId: pending.placeId,
                addedBy: pending.userId,
                googlePlaceId: pending.place.googlePlaceId
            )
            if !ListPlaceOptimisticUpdate.sameId(savedPlaceId, pending.placeId) {
                rekeyOptimisticAdd(pending, to: savedPlaceId)
            }
        } catch {
            print("❌ [ListsPlaceMutationsViewModel] Failed to add place to list, rolling back: \(error)")
            rollBackOptimisticAdd(pending)
            throw error
        }
    }

    /// Undoes `applyOptimisticAdd` after a failed save.
    private func rollBackOptimisticAdd(_ pending: PendingAdd) {
        guard let dataVM = dataViewModel else { return }
        if pending.didInsert {
            let places = ListPlaceOptimisticUpdate.revertingAdd(placeId: pending.placeId, from: dataVM.places(forListId: pending.listId))
            dataVM.storePlaces(places, forListId: pending.listId)
            let restored = ListPlaceOptimisticUpdate.countAfterRollback(
                previousCount: pending.previousCount,
                currentCount: dataVM.cachedCount(forListId: pending.listId)
            )
            dataVM.storeCount(restored, forListId: pending.listId)
        }
        if pending.addedSaver {
            onPlaceSaversUpdate?(pending.placeId, pending.userId, false)
        }
        onAnnotationPlacesRecalculate?()
    }

    /// The server saved the item under the place's real id (resolved by google_places_id).
    /// Swap the optimistic entry over so the cache matches the database.
    private func rekeyOptimisticAdd(_ pending: PendingAdd, to savedPlaceId: String) {
        guard let dataVM = dataViewModel else { return }
        if pending.didInsert {
            let places = ListPlaceOptimisticUpdate.replacingPlaceId(pending.placeId, with: savedPlaceId, in: dataVM.places(forListId: pending.listId))
            dataVM.storePlaces(places, forListId: pending.listId)
        }
        if let realUUID = UUID(uuidString: savedPlaceId) {
            var resolvedPlace = pending.place
            resolvedPlace.id = realUUID
            onPlacesUpdate?(savedPlaceId, resolvedPlace)
        }
        onPlaceSaversUpdate?(savedPlaceId, pending.userId, true)
        if pending.addedSaver {
            onPlaceSaversUpdate?(pending.placeId, pending.userId, false)
        }
        onAnnotationPlacesRecalculate?()
    }

    /// Add a place to a list (old UUID-based format) - delegates to addPlaceToLightweightList.
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        if place.hasPlaceholderID {
            // Resolve the real id first; never save the shared placeholder id.
            Task { @MainActor [weak self] in
                guard let resolved = try? await PlaceRepository.shared.ensureResolved(place) else {
                    print("❌ [ListsPlaceMutationsViewModel] Place still loading; not added to list")
                    return
                }
                self?.addPlaceToList(listId: listId, place: resolved)
            }
            return
        }
        guard let dataVM = dataViewModel else { return }

        let listIdString = listId.uuidString
        guard let listIndex = dataVM.userLists.firstIndex(where: { $0.id == listId }) else { return }

        // Delegate to new implementation for core functionality
        addPlaceToLightweightList(listId: listIdString, place: place)

        // Legacy-specific: Update old PlaceList format
        let placeForList = place.toPlace()
        var places = dataVM.userListsPlaces[listIdString] ?? []
        if !places.contains(place.id.uuidString) {
            places.append(place.id.uuidString)
            dataVM.userListsPlaces[listIdString] = places
        }

        if !dataVM.userLists[listIndex].places.contains(where: { $0.id == place.id }) {
            dataVM.userLists[listIndex].places.append(placeForList)
            dataVM.placeListCounts[listId] = dataVM.userLists[listIndex].places.count
        }

        // Legacy-specific: Update average coordinates and pagination
        distanceSortingViewModel?.recalculateAverageCoordinates(for: listId)
        placePaginationViewModel?.resetListPagination(listId: listId)
    }

    // MARK: - Remove Place from List

    /// Remove a place from a lightweight list using a DetailPlace reference.
    func removePlaceFromLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        removePlaceFromLightweightList(listId: listId, placeId: place.id.uuidString, updatedCount: updatedCount)
    }

    /// Remove a place from a lightweight list by place ID.
    func removePlaceFromLightweightList(listId: String, placeId: String, updatedCount: Int? = nil) {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }

        var didRemove = false

        // Update local lightweightPlaceListPlaces
        if var places = dataVM.places(forListId: listId) {
            let originalCount = places.count
            places.removeAll { $0.place_id.caseInsensitiveCompare(placeId) == .orderedSame }
            if places.count != originalCount {
                didRemove = true
            }
            dataVM.storePlaces(places, forListId: listId)
        }

        if didRemove {
            if let finalCount = updatedCount {
                dataVM.storeCount(finalCount, forListId: listId)
            } else {
                let metadata = dataVM.lightweightPlaceLists.first(where: {
                    ListPlaceCount.normalizedId($0.list_id) == ListPlaceCount.normalizedId(listId)
                })?.place_count
                let startingCount = dataVM.cachedCount(forListId: listId) ?? metadata ?? 0
                dataVM.storeCount(max(startingCount - 1, 0), forListId: listId)
            }
        }

        // Remove current user as saver
        onPlaceSaversUpdate?(placeId, userId, false)

        // Recalculate map annotations
        onAnnotationPlacesRecalculate?()

        // Persist to Supabase
        Task {
            do {
                try await SupabaseUserService.shared.removePlaceFromList(listId: listId, placeId: placeId)
            } catch {
                print("❌ [ListsPlaceMutationsViewModel] Failed to remove place from lightweight list: \(error)")
            }
        }
    }

    /// Remove a place from a list (old UUID-based format).
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        guard let dataVM = dataViewModel,
              let userId = userSession?.currentUserId else { return }

        let listIdString = listId.uuidString
        guard var places = dataVM.userListsPlaces[listIdString],
              let index = places.firstIndex(of: place.id.uuidString),
              let list = dataVM.userLists.first(where: { $0.id == listId }) else {
            return
        }

        places.remove(at: index)
        dataVM.userListsPlaces[listIdString] = places

        let placeForList = place.toPlace()

        placeService.removePlaceFromList(userId: userId, listId: list.id.uuidString, placeId: placeForList.id.uuidString) { error in
            if let error = error {
                print("❌ Error removing place from list: \(error)")
            }
        }

        // Recalculate average coordinates for this list
        distanceSortingViewModel?.recalculateAverageCoordinates(for: listId)

        // Reset pagination to reflect the removed place
        placePaginationViewModel?.resetListPagination(listId: listId)
    }
}
