//
//  ListPlacePagination.swift
//  loc
//
//  Extracted from ProfileViewModel.swift.
//

import Foundation

/// Tracks pagination state for places within a single list.
struct ListPlacePagination {
    var allPlaceIds: [String] = []
    var loadedPlaceIds: [String] = []
    var currentPage: Int = 0
    var placesPerPage: Int = 5
    var isLoadingMore: Bool = false
    var hasMorePlaces: Bool = true

    var displayedPlaceIds: [String] {
        return loadedPlaceIds
    }

    var totalPlaces: Int {
        return allPlaceIds.count
    }

    var loadedCount: Int {
        return loadedPlaceIds.count
    }
}
