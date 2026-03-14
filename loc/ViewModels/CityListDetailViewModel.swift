//
//  CityListDetailViewModel.swift
//  loc
//
//  ViewModel for the city list detail view, fetching places with pagination and type filtering.
//

import Foundation

@MainActor
class CityListDetailViewModel: ObservableObject {
    @Published var places: [LightweightPlace] = []
    @Published var isLoading: Bool = true
    @Published var hasMorePages: Bool = true
    @Published private(set) var hasLoadedInitialPlaces: Bool = false

    /// Currently selected type filter (nil = show all)
    @Published var selectedType: String? = nil

    private let userService = ServiceContainer.shared.userService
    private let listId: String
    private var currentPage = 1
    private let pageSize = 20

    init(listId: String) {
        self.listId = listId
    }

    /// Unique place types extracted from loaded places, sorted alphabetically.
    var availableTypes: [String] {
        let types = Set(places.compactMap { $0.place_type })
        return types.sorted()
    }

    /// Places filtered by the selected type.
    var filteredPlaces: [LightweightPlace] {
        guard let selected = selectedType else { return places }
        return places.filter { $0.place_type == selected }
    }

    /// Formatted display name for a place type.
    func displayName(for type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Toggles the type filter on or off.
    func toggleTypeFilter(_ type: String) {
        if selectedType == type {
            selectedType = nil
        } else {
            selectedType = type
        }
    }

    /// Fetches the first page of places for the list.
    func loadPlaces() async {
        guard !hasLoadedInitialPlaces else { return }
        isLoading = true
        currentPage = 1

        do {
            let fetched = try await userService.fetchPlacesForPlaceList(
                listId: listId,
                page: 1,
                pageSize: pageSize
            )
            places = fetched
            hasMorePages = fetched.count >= pageSize
        } catch {
            print("❌ [CityListDetailVM] Error loading places: \(error.localizedDescription)")
        }

        hasLoadedInitialPlaces = true
        isLoading = false
    }

    /// Loads the next page when the user scrolls to the given place.
    func loadMoreIfNeeded(currentPlace: LightweightPlace) async {
        guard hasMorePages, !isLoading else { return }
        guard currentPlace.id == places.last?.id else { return }

        currentPage += 1

        do {
            let fetched = try await userService.fetchPlacesForPlaceList(
                listId: listId,
                page: currentPage,
                pageSize: pageSize
            )
            places.append(contentsOf: fetched)
            hasMorePages = fetched.count >= pageSize
        } catch {
            print("❌ [CityListDetailVM] Error loading more places: \(error.localizedDescription)")
            currentPage -= 1
        }
    }
}
