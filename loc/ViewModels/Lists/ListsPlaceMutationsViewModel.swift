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

    /// Add a place to a lightweight list (current format).
    func addPlaceToLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }

        let placeId = place.id.uuidString

        // Create lightweight place object with added_by info for collaborative lists
        let userInfo = getUserInfo?()
        let lightweightPlace = LightweightPlace(
            place_id: placeId,
            name: place.name,
            latest_review_photo: place.photoUrls?.first,
            external_place_id: nil,
            tiktok_url: nil,
            added_by_user_id: userId,
            added_by_name: userInfo?.fullName,
            added_by_photo_url: userInfo?.profilePhotoURL?.absoluteString
        )

        var didInsert = false

        // Update local lightweightPlaceListPlaces
        // Insert at index 0 so new places appear first (matches DB sort_order behavior)
        if var existingPlaces = dataVM.lightweightPlaceListPlaces[listId] {
            if !existingPlaces.contains(where: { $0.place_id == placeId }) {
                existingPlaces.insert(lightweightPlace, at: 0)
                dataVM.lightweightPlaceListPlaces[listId] = existingPlaces
                didInsert = true
            }
        } else {
            dataVM.lightweightPlaceListPlaces[listId] = [lightweightPlace]
            didInsert = true
        }

        if didInsert {
            if let finalCount = updatedCount {
                dataVM.lightweightPlaceListCounts[listId] = finalCount
            } else {
                let startingCount = dataVM.lightweightPlaceListCounts[listId]
                    ?? dataVM.lightweightPlaceLists.first(where: { $0.list_id == listId })?.place_count
                    ?? 0
                dataVM.lightweightPlaceListCounts[listId] = startingCount + 1
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
                print("❌ [ListsPlaceMutationsViewModel] Failed to add place to list: \(error)")
            }
        }
    }

    /// Add a place to a list (old UUID-based format) - delegates to addPlaceToLightweightList.
    func addPlaceToList(listId: UUID, place: DetailPlace) {
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

    /// Remove a place from a lightweight list.
    func removePlaceFromLightweightList(listId: String, place: DetailPlace, updatedCount: Int? = nil) {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }

        var didRemove = false

        // Update local lightweightPlaceListPlaces
        if var places = dataVM.lightweightPlaceListPlaces[listId] {
            let originalCount = places.count
            places.removeAll { $0.place_id == place.id.uuidString }
            if places.count != originalCount {
                didRemove = true
            }
            dataVM.lightweightPlaceListPlaces[listId] = places
        }

        if didRemove {
            if let finalCount = updatedCount {
                dataVM.lightweightPlaceListCounts[listId] = finalCount
            } else {
                let startingCount = dataVM.lightweightPlaceListCounts[listId]
                    ?? dataVM.lightweightPlaceLists.first(where: { $0.list_id == listId })?.place_count
                    ?? 0
                dataVM.lightweightPlaceListCounts[listId] = max(startingCount - 1, 0)
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
