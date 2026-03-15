//
//  TripAddPlaceToItineraryViewModel.swift
//  loc
//
//  ViewModel for adding a place to a trip day from lists or search
//  Single Responsibility: Browse user lists and select places for a trip day
//

import Foundation

@MainActor
class TripAddPlaceToItineraryViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var userLists: [LightweightPlaceList] = []
    @Published private(set) var listPlaces: [String: [LightweightPlace]] = [:]
    @Published private(set) var isLoadingLists = false
    @Published private(set) var isLoadingPlacesForList = false
    @Published var selectedListId: String?

    // MARK: - Dependencies

    private let userService = ServiceContainer.shared.userService
    private let collaborationService = CollaborationService.shared

    // MARK: - Load User Lists

    /// Fetches the user's owned, shared, and collaborative lists.
    func loadUserLists(userId: String) async {
        isLoadingLists = true
        defer { isLoadingLists = false }

        // Fetch owned lists without location sorting
        var ownedLists: [LightweightPlaceList] = []
        do {
            ownedLists = try await userService.fetchPlaceListsWithoutLocation(
                userId: userId, page: 1, pageSize: 50
            )
        } catch {
            print("[TripAddPlaceVM] Failed to load owned lists: \(error)")
        }

        // Fetch shared and collaborative lists
        var sharedLists: [SharedListInfo] = []
        var collaborativeOwnedLists: [CollaborativeOwnedList] = []

        do {
            sharedLists = try await collaborationService.fetchSharedLists(userId: userId)
        } catch {
            print("[TripAddPlaceVM] Failed to load shared lists: \(error)")
        }

        do {
            collaborativeOwnedLists = try await collaborationService.fetchCollaborativeOwnedLists(userId: userId)
        } catch {
            print("[TripAddPlaceVM] Failed to load collaborative lists: \(error)")
        }

        // Merge and deduplicate by list_id
        let ownedIds = Set(ownedLists.map { $0.list_id })
        let sharedAsLightweight = sharedLists.map { $0.toLightweightPlaceList() }
        let collaborativeAsLightweight = collaborativeOwnedLists
            .map { $0.toLightweightPlaceList() }
            .filter { !ownedIds.contains($0.list_id) }

        userLists = ownedLists + collaborativeAsLightweight + sharedAsLightweight

        // Load preview places for collage photos
        if !userLists.isEmpty {
            await loadPlacesForLists(userLists)
        }
    }

    // MARK: - Place Loading

    /// Loads the first few places per list for collage photo previews.
    private func loadPlacesForLists(_ lists: [LightweightPlaceList]) async {
        await withTaskGroup(of: (String, [LightweightPlace]).self) { group in
            for list in lists {
                group.addTask {
                    do {
                        let places = try await self.userService.fetchPlacesForPlaceList(
                            listId: list.list_id, page: 1, pageSize: 3
                        )
                        return (list.list_id, places)
                    } catch {
                        return (list.list_id, [])
                    }
                }
            }

            for await (listId, places) in group {
                listPlaces[listId] = places
            }
        }
    }

    /// Loads all places for a specific list when the user taps it.
    func loadAllPlacesForList(listId: String) async {
        selectedListId = listId
        isLoadingPlacesForList = true
        defer { isLoadingPlacesForList = false }

        do {
            let places = try await userService.fetchPlacesForPlaceList(
                listId: listId, page: 1, pageSize: 100
            )
            listPlaces[listId] = places
        } catch {
            print("[TripAddPlaceVM] Failed to load places for list \(listId): \(error)")
        }
    }

    /// Resets state when going back to list selection.
    func clearPlaces() {
        selectedListId = nil
    }
}
