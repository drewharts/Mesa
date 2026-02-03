//
//  MapExternalUserViewModel.swift
//  loc
//
//  Handles external user content filtering for map annotations.
//

import Foundation

@MainActor
class MapExternalUserViewModel: ObservableObject {
    @Published var externalUserId: String? = nil
    @Published var showingExternalReviewsOnMap: Bool = false
    @Published var showingExternalFavoritesOnMap: Bool = false
    @Published var externalListId: String? = nil

    /// Callback invoked when external user filter changes, allowing parent to trigger viewport reload.
    var onFilterChanged: (() -> Void)?

    /// Callback invoked when an external user is selected, allowing parent to load their profile photo.
    var onExternalUserSelected: ((String, URL?) -> Void)?

    // MARK: - Computed Properties

    var hasActiveExternalFilter: Bool {
        externalUserId != nil
    }

    // MARK: - External User Filtering

    /// Shows external user's reviews on the map with filtered annotations.
    func selectExternalReviews(userId: String, userPhotoUrl: URL?) {
        externalUserId = userId
        showingExternalReviewsOnMap = true
        showingExternalFavoritesOnMap = false
        externalListId = nil
        onFilterChanged?()
        onExternalUserSelected?(userId, userPhotoUrl)
    }

    /// Shows external user's list on the map with filtered annotations.
    func selectExternalList(listId: String, userId: String, userPhotoUrl: URL?) {
        externalUserId = userId
        externalListId = listId
        showingExternalReviewsOnMap = false
        showingExternalFavoritesOnMap = false
        onFilterChanged?()
        onExternalUserSelected?(userId, userPhotoUrl)
    }

    /// Shows external user's favorites on the map with filtered annotations.
    func selectExternalFavorites(userId: String, userPhotoUrl: URL?) {
        externalUserId = userId
        showingExternalFavoritesOnMap = true
        showingExternalReviewsOnMap = false
        externalListId = nil
        onFilterChanged?()
        onExternalUserSelected?(userId, userPhotoUrl)
    }

    /// Clears all external user filters.
    func clearAllFilters() {
        externalUserId = nil
        showingExternalReviewsOnMap = false
        showingExternalFavoritesOnMap = false
        externalListId = nil
        // Note: onFilterChanged is NOT called here - parent coordinates this
    }
}
