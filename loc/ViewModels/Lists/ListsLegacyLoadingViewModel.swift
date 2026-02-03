//
//  ListsLegacyLoadingViewModel.swift
//  loc
//
//  Child ViewModel for legacy DetailPlace-based lazy loading.
//

import SwiftUI

/// Manages legacy DetailPlace-based lazy loading for lists.
@MainActor
class ListsLegacyLoadingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Loaded list IDs (for lazy loading).
    @Published var loadedListIds: Set<UUID> = []

    /// Currently loading list IDs.
    @Published var loadingListIds: Set<UUID> = []

    // MARK: - Private State

    private let maxConcurrentListLoads = 2
    private var activeListLoadTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Dependencies

    private let placeService: PlaceService

    // MARK: - ViewModel References

    private weak var dataViewModel: ListsDataViewModel?
    private weak var placePaginationViewModel: ListsPlacePaginationViewModel?

    // MARK: - Callbacks

    /// Called to get current user ID.
    var getCurrentUserId: (() -> String?)?

    /// Called to set parent's loading state.
    var onSetLoading: ((Bool) -> Void)?

    /// Called when places dictionary needs updating.
    var onPlacesUpdate: ((String, DetailPlace?) -> Void)?

    /// Called to fetch place image.
    var onFetchPlaceImage: ((String) -> Void)?

    /// Called to check if a place exists in the places dictionary.
    var hasPlace: ((String) -> Bool)?

    // MARK: - Initialization

    /// Initializes the legacy loading view model with required dependencies.
    init(placeService: PlaceService, dataViewModel: ListsDataViewModel) {
        self.placeService = placeService
        self.dataViewModel = dataViewModel
    }

    /// Sets the place pagination view model reference.
    func setPlacePaginationViewModel(_ viewModel: ListsPlacePaginationViewModel) {
        self.placePaginationViewModel = viewModel
    }

    // MARK: - Legacy List Loading (DetailPlace-based)

    /// Ensures lists are loaded with DetailPlace data for legacy views.
    func ensureListsLoaded() {
        guard let userId = getCurrentUserId?(),
              let dataVM = dataViewModel else { return }

        // Check if we need to load places for the first 3 lists
        let firstThreeLists = Array(dataVM.userLists.prefix(3))
        let needsPlaceLoading = firstThreeLists.contains { list in
            dataVM.userListsPlaces[list.id.uuidString]?.isEmpty != false
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
                let lists = dataVM.userLists

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
                            dataVM.userListsPlaces[listId] = placeIds

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
                                dataVM.placeListCounts[uuid] = count
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
                print("❌ [ListsLegacyLoadingViewModel] ensureListsLoaded: Error loading places for lists: \(error.localizedDescription)")
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
        guard let dataVM = dataViewModel else { return }

        // Check if places are already loaded (e.g., from preloading)
        let alreadyLoaded = await MainActor.run {
            let listIdString = listId.uuidString
            let hasPlaceIds = dataVM.userListsPlaces[listIdString]?.isEmpty == false
            let hasDetailPlaces = dataVM.userListsPlaces[listIdString]?.allSatisfy { placeId in
                hasPlace?(placeId) ?? false
            } ?? false
            return hasPlaceIds && hasDetailPlaces
        }

        if alreadyLoaded {
            await MainActor.run {
                self.loadedListIds.insert(listId)
                self.placePaginationViewModel?.initializeListPaginationIfNeeded(listId: listId)
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
                    dataVM.userListsPlaces[listId.uuidString] = placeIds

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
                    self.placePaginationViewModel?.initializeListPaginationIfNeeded(listId: listId)
                }
            }
        } catch {
            print("❌ [ListsLegacyLoadingViewModel] performListLoad: Error loading places for list \(listId): \(error)")
            await MainActor.run {
                self.loadingListIds.remove(listId)
                self.activeListLoadTasks.removeValue(forKey: listId)
            }
        }
    }

    /// Load more lists when user scrolls (lazy loading).
    func loadMoreListsIfNeeded() {
        guard let dataVM = dataViewModel else { return }

        // Find the next 3 lists that haven't been loaded yet
        let unloadedLists = dataVM.userLists.filter { !loadedListIds.contains($0.id) && !loadingListIds.contains($0.id) }
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
                        dataVM.userListsPlaces[listId] = placeIds

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
                print("❌ [ListsLegacyLoadingViewModel] loadMoreListsIfNeeded: Error loading more lists: \(error)")
                await MainActor.run {
                    for list in nextThreeLists {
                        self.loadingListIds.remove(list.id)
                    }
                }
            }
        }
    }

    // MARK: - Reset

    /// Resets legacy loading state.
    func resetLegacyLoadingState() {
        loadedListIds.removeAll()
        loadingListIds.removeAll()
        activeListLoadTasks.values.forEach { $0.cancel() }
        activeListLoadTasks.removeAll()
    }
}
