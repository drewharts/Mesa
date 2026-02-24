//
//  TripMapPlacePickerViewModel.swift
//  loc
//
//  ViewModel for the map-based place picker in trip itinerary
//  Single Responsibility: Load and expose all user's saved places for map display
//

import Foundation

@MainActor
class TripMapPlacePickerViewModel: ObservableObject {
    // MARK: - Published State

    @Published var allPlaces: [LightweightPlace] = []
    @Published var isLoading = false

    // MARK: - Properties

    /// Place IDs already in the trip (for "already added" indicators).
    var alreadyAddedPlaceIds: Set<String> = []

    /// Places that have valid coordinates for map display.
    var mappablePlaces: [LightweightPlace] {
        allPlaces.filter { $0.latitude != nil && $0.longitude != nil }
    }

    // MARK: - Dependencies

    private let userService = ServiceContainer.shared.userService
    private let collaborationService = CollaborationService.shared

    // MARK: - Load All User Places

    /// Fetches all places from the user's owned, shared, and collaborative lists.
    func loadAllUserPlaces(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        // 1. Gather all lists
        var allLists: [LightweightPlaceList] = []

        do {
            let ownedLists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId, page: 1, pageSize: 50
            )
            allLists.append(contentsOf: ownedLists)
        } catch {
            print("[TripMapPickerVM] Failed to load owned lists: \(error)")
        }

        let ownedIds = Set(allLists.map { $0.list_id })

        do {
            let sharedLists = try await collaborationService.fetchSharedLists(userId: userId)
            allLists.append(contentsOf: sharedLists.map { $0.toLightweightPlaceList() })
        } catch {
            print("[TripMapPickerVM] Failed to load shared lists: \(error)")
        }

        do {
            let collaborativeLists = try await collaborationService.fetchCollaborativeOwnedLists(userId: userId)
            let filtered = collaborativeLists
                .map { $0.toLightweightPlaceList() }
                .filter { !ownedIds.contains($0.list_id) }
            allLists.append(contentsOf: filtered)
        } catch {
            print("[TripMapPickerVM] Failed to load collaborative lists: \(error)")
        }

        // 2. Parallel-load all places per list
        var placesById: [String: LightweightPlace] = [:]

        await withTaskGroup(of: [LightweightPlace].self) { group in
            for list in allLists {
                group.addTask {
                    do {
                        return try await self.userService.fetchPlacesForPlaceList(
                            listId: list.list_id, page: 1, pageSize: 100
                        )
                    } catch {
                        return []
                    }
                }
            }

            for await places in group {
                for place in places {
                    placesById[place.place_id] = place
                }
            }
        }

        allPlaces = Array(placesById.values)
    }
}
