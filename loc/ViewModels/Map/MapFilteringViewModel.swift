//
//  MapFilteringViewModel.swift
//  loc
//
//  Handles user content filtering for map annotations (lists, TikToks, reviews, favorites, my places, keywords).
//

import Foundation

@MainActor
class MapFilteringViewModel: ObservableObject {
    @Published var selectedListId: String? = nil
    @Published var showingTikToksOnMap: Bool = false
    @Published var showingReviewsOnMap: Bool = false
    @Published var showingFavoritesOnMap: Bool = false
    @Published var showingMyPlacesOnMap: Bool = false
    @Published var showingKeywordResultsPopup: Bool = false
    @Published var keywordTypesFilter: [String]? = nil

    /// Callback invoked when any filter changes, allowing parent to trigger viewport reload.
    var onFilterChanged: (() -> Void)?

    // MARK: - Computed Properties

    var hasActiveFilter: Bool {
        selectedListId != nil ||
        showingTikToksOnMap ||
        showingReviewsOnMap ||
        showingFavoritesOnMap ||
        showingMyPlacesOnMap ||
        showingKeywordResultsPopup
    }

    // MARK: - List Filtering

    /// Validates that a list exists and sets it as the selected list for filtering map annotations.
    func selectList(_ listId: String, availableLists: [LightweightPlaceList]) -> Bool {
        guard availableLists.contains(where: { $0.id == listId }) else {
            return false
        }

        selectedListId = listId
        showingTikToksOnMap = false
        showingReviewsOnMap = false
        showingFavoritesOnMap = false
        showingMyPlacesOnMap = false
        showingKeywordResultsPopup = false
        keywordTypesFilter = nil
        onFilterChanged?()
        return true
    }

    /// Clears the list filter.
    func clearListFilter() {
        selectedListId = nil
        onFilterChanged?()
    }

    // MARK: - Content Type Filtering

    /// Sets the map to show only TikTok places.
    func selectTikToks() {
        showingTikToksOnMap = true
        showingReviewsOnMap = false
        showingFavoritesOnMap = false
        showingMyPlacesOnMap = false
        selectedListId = nil
        showingKeywordResultsPopup = false
        keywordTypesFilter = nil
        onFilterChanged?()
    }

    /// Sets the map to show only reviewed places.
    func selectReviews() {
        showingReviewsOnMap = true
        showingTikToksOnMap = false
        showingFavoritesOnMap = false
        showingMyPlacesOnMap = false
        selectedListId = nil
        showingKeywordResultsPopup = false
        keywordTypesFilter = nil
        onFilterChanged?()
    }

    /// Sets the map to show only favorite places.
    func selectFavorites() {
        showingFavoritesOnMap = true
        showingTikToksOnMap = false
        showingReviewsOnMap = false
        showingMyPlacesOnMap = false
        selectedListId = nil
        showingKeywordResultsPopup = false
        keywordTypesFilter = nil
        onFilterChanged?()
    }

    /// Sets the map to show only user's created places.
    func selectMyPlaces() {
        showingMyPlacesOnMap = true
        showingTikToksOnMap = false
        showingReviewsOnMap = false
        showingFavoritesOnMap = false
        selectedListId = nil
        showingKeywordResultsPopup = false
        keywordTypesFilter = nil
        onFilterChanged?()
    }

    /// Shows keyword search results on the map with filtered annotations.
    func selectKeywordResults(keyword: String, types: [String]) {
        showingKeywordResultsPopup = true
        keywordTypesFilter = types
        showingTikToksOnMap = false
        showingReviewsOnMap = false
        showingFavoritesOnMap = false
        showingMyPlacesOnMap = false
        selectedListId = nil
        onFilterChanged?()
    }

    /// Clears all user filters.
    func clearAllFilters() {
        selectedListId = nil
        showingTikToksOnMap = false
        showingReviewsOnMap = false
        showingFavoritesOnMap = false
        showingMyPlacesOnMap = false
        showingKeywordResultsPopup = false
        keywordTypesFilter = nil
        onFilterChanged?()
    }
}
