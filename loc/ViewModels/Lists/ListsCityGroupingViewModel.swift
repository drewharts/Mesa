//
//  ListsCityGroupingViewModel.swift
//  loc
//
//  Child ViewModel for grouping lists by city and managing collapse state.
//

import SwiftUI

/// Manages city-based grouping and section collapse state for place lists.
@MainActor
class ListsCityGroupingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether city grouping is enabled.
    @Published var isGroupingEnabled: Bool = true

    /// Set of city names whose sections are collapsed.
    @Published var collapsedCities: Set<String> = []

    // MARK: - Dependencies

    private weak var searchViewModel: ListsSearchViewModel?

    // MARK: - Constants

    private let otherGroupName = "Other"

    // MARK: - Initialization

    /// Initializes the city grouping view model with a reference to the search view model.
    init(searchViewModel: ListsSearchViewModel) {
        self.searchViewModel = searchViewModel
    }

    // MARK: - Computed Properties

    /// Returns true when grouped view should be shown (grouping on and not searching).
    var shouldShowGrouped: Bool {
        guard isGroupingEnabled else { return false }
        guard let searchVM = searchViewModel else { return true }
        return searchVM.listSearchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Grouping

    /// Groups a flat list of place lists by their city, ordered by minimum distance_meters.
    func groupedLists(from lists: [LightweightPlaceList]) -> [CityListGroup] {
        var cityBuckets: [String: [LightweightPlaceList]] = [:]
        var cityMinIndex: [String: Int] = [:]

        for (index, list) in lists.enumerated() {
            let key = list.city ?? otherGroupName
            cityBuckets[key, default: []].append(list)
            if cityMinIndex[key] == nil || index < cityMinIndex[key]! {
                cityMinIndex[key] = index
            }
        }

        let sorted = cityBuckets.keys.sorted { a, b in
            if a == otherGroupName { return false }
            if b == otherGroupName { return true }
            return (cityMinIndex[a] ?? Int.max) < (cityMinIndex[b] ?? Int.max)
        }

        return sorted.map { city in
            CityListGroup(city: city, lists: cityBuckets[city] ?? [])
        }
    }

    // MARK: - Collapse State

    /// Toggles the collapsed state of a city section.
    func toggleCity(_ city: String) {
        if collapsedCities.contains(city) {
            collapsedCities.remove(city)
        } else {
            collapsedCities.insert(city)
        }
    }

    /// Returns whether a city section is currently collapsed.
    func isCityCollapsed(_ city: String) -> Bool {
        collapsedCities.contains(city)
    }

    // MARK: - Reset

    /// Resets grouping state to defaults.
    func resetGroupingState() {
        isGroupingEnabled = true
        collapsedCities.removeAll()
    }
}
