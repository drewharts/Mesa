//
//  ListsSearchViewModel.swift
//  loc
//
//  Child ViewModel for list search and filter operations.
//

import SwiftUI
import CoreLocation

/// Manages list search and filter operations.
@MainActor
class ListsSearchViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Show only shared/collaborative lists.
    @Published var showOnlySharedLists: Bool = false

    /// Searching lists state.
    @Published var isSearchingLists: Bool = false

    /// List search text.
    @Published var listSearchText: String = ""

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?
    private weak var locationManager: LocationManager?

    // MARK: - ViewModel References

    private weak var dataViewModel: ListsDataViewModel?
    private weak var loadingViewModel: ListsLoadingViewModel?

    // MARK: - Initialization

    /// Initializes the search view model with required dependencies.
    init(userService: UserService, userSession: UserSession, locationManager: LocationManager, dataViewModel: ListsDataViewModel, loadingViewModel: ListsLoadingViewModel) {
        self.userService = userService
        self.userSession = userSession
        self.locationManager = locationManager
        self.dataViewModel = dataViewModel
        self.loadingViewModel = loadingViewModel
    }

    // MARK: - Computed Properties

    /// Returns filtered lists based on current filter state.
    var filteredPlaceLists: [LightweightPlaceList] {
        guard let dataVM = dataViewModel else { return [] }
        if showOnlySharedLists {
            return dataVM.lightweightPlaceLists.filter { $0.isCollaborative }
        }
        return dataVM.lightweightPlaceLists
    }

    /// Count of collaborative lists.
    var collaborativeListCount: Int {
        guard let dataVM = dataViewModel else { return 0 }
        return dataVM.lightweightPlaceLists.filter { $0.isCollaborative }.count
    }

    /// Whether there are any collaborative lists to filter.
    var hasSharedLists: Bool {
        collaborativeListCount > 0
    }

    /// Whether the Shared filter button should be interactive.
    var canInteractWithSharedFilter: Bool {
        guard let loadingVM = loadingViewModel else { return true }
        return !loadingVM.isLoadingInitialLists
    }

    // MARK: - Search

    /// Performs server-side search across all user lists.
    func performListSearch() async {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel else { return }

        let searchTerm = listSearchText.trimmingCharacters(in: .whitespaces)
        guard !searchTerm.isEmpty else { return }

        do {
            let searchResults = try await PlaceListService.shared.searchListsByName(
                userId: userId,
                searchTerm: listSearchText
            )

            dataVM.lightweightPlaceLists = searchResults

            for list in searchResults {
                if dataVM.lightweightPlaceListCounts[list.list_id] == nil {
                    dataVM.lightweightPlaceListCounts[list.list_id] = list.place_count
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
                        dataVM.setPlacesForList(listId: listId, places: places)
                    }
                }
            }
        } catch {
            print("❌ [ListsSearchViewModel] Error searching lists: \(error)")
        }
    }

    /// Reloads lists when exiting search mode.
    func reloadListsAfterSearch() async {
        guard let userId = userSession?.currentUserId,
              let dataVM = dataViewModel,
              let loadingVM = loadingViewModel else { return }

        loadingVM.isLoadingInitialLists = true
        defer { loadingVM.isLoadingInitialLists = false }

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

            dataVM.lightweightPlaceLists = lists
            dataVM.placeListsCurrentPage = 1
            dataVM.hasMorePlaceLists = lists.count >= 6

            await loadingVM.loadPlacesForLists(lists)
        } catch {
            print("❌ [ListsSearchViewModel] Error reloading lists after search: \(error)")
        }
    }

    // MARK: - Reset

    /// Resets search state.
    func resetSearchState() {
        showOnlySharedLists = false
        isSearchingLists = false
        listSearchText = ""
    }
}
