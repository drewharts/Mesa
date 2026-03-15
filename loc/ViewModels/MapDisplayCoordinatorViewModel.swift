//
//  MapDisplayCoordinatorViewModel.swift
//  loc
//
//  Single Responsibility: Coordinates map display for external user data.
//  Handles showing reviews, lists, and favorites on the map from external profiles.
//

import Foundation
import MapKit
import SwiftUI

/// Coordinates map display for external user data.
/// Single Responsibility: Manages map display triggers and data for external profiles.
@MainActor
class MapDisplayCoordinatorViewModel: ObservableObject {
    // MARK: - Trip Map Display

    /// Trip annotations currently shown on the main map.
    @Published var activeTripAnnotations: [TripMapAnnotation] = []

    /// The ID of the trip currently shown on the main map.
    @Published var activeTripId: String? = nil

    /// Whether trip annotations are currently displayed on the map.
    var hasTripOverlay: Bool {
        !activeTripAnnotations.isEmpty
    }

    /// Place ID tapped on a trip map annotation, observed by TripDetailView for navigation.
    @Published var tappedTripPlaceId: String?

    // MARK: - Map Display Triggers

    /// Triggers map sheet to show external user's reviews
    @Published var showExternalReviewsOnMap = false

    /// Triggers map sheet to show external user's list (value is list ID)
    @Published var showExternalListOnMap: String? = nil

    /// Triggers map sheet to show external user's favorites
    @Published var showExternalFavoritesOnMap = false

    // MARK: - Map Display Context

    /// User ID for the map display context (separate from navigation state)
    @Published var mapDisplayUserId: String?

    /// User's profile photo URL for annotations
    @Published var mapDisplayUserPhotoUrl: String?

    /// User's name for popup titles (e.g., "User's Reviews")
    @Published var mapDisplayUserName: String?

    // MARK: - Map Display Data

    /// Reviews data for map display
    @Published var mapDisplayReviews: [LightweightPlace] = []

    /// Total count of reviewed places for map display
    @Published var mapDisplayReviewsCount: Int = 0

    /// Favorites data for map display
    @Published var mapDisplayFavorites: [LightweightPlace] = []

    /// Lists data for map display
    @Published var mapDisplayLists: [LightweightPlaceList] = []

    /// Places for each list in map display
    @Published var mapDisplayListPlaces: [String: [LightweightPlace]] = [:]

    // MARK: - Public Methods

    /// Shows external user's reviews on the map (dismisses profile, shows map sheet).
    /// - Parameters:
    ///   - userId: The user whose reviews to display
    ///   - userName: The user's name for popup title
    ///   - userPhotoUrl: The user's profile photo URL for annotations
    ///   - reviews: The reviewed places to display
    ///   - totalCount: Total count of reviewed places
    ///   - dismissProfile: Closure to dismiss the profile view
    func triggerExternalReviewsOnMap(
        userId: String,
        userName: String?,
        userPhotoUrl: String?,
        reviews: [LightweightPlace],
        totalCount: Int,
        dismissProfile: @escaping () -> Void
    ) {
        mapDisplayUserId = userId
        mapDisplayUserName = userName
        mapDisplayUserPhotoUrl = userPhotoUrl
        mapDisplayReviews = reviews
        mapDisplayReviewsCount = totalCount

        dismissProfile()

        // Defer map trigger to allow profile dismiss animation to complete before presenting new sheet
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            showExternalReviewsOnMap = true
        }
    }

    /// Shows external user's list on the map (dismisses profile, shows map sheet).
    /// - Parameters:
    ///   - listId: The list ID to display
    ///   - userId: The user who owns the list
    ///   - userName: The user's name for popup title
    ///   - userPhotoUrl: The user's profile photo URL for annotations
    ///   - lists: The user's lists to display in the popup
    ///   - listPlaces: Dictionary of list ID to places for each list
    ///   - dismissProfile: Closure to dismiss the profile view
    func triggerExternalListOnMap(
        listId: String,
        userId: String,
        userName: String?,
        userPhotoUrl: String?,
        lists: [LightweightPlaceList],
        listPlaces: [String: [LightweightPlace]],
        dismissProfile: @escaping () -> Void
    ) {
        mapDisplayUserId = userId
        mapDisplayUserName = userName
        mapDisplayUserPhotoUrl = userPhotoUrl
        mapDisplayLists = lists
        mapDisplayListPlaces = listPlaces

        dismissProfile()

        // Defer map trigger to allow profile dismiss animation to complete before presenting new sheet
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            showExternalListOnMap = listId
        }
    }

    /// Shows external user's favorites on the map (dismisses profile, shows map sheet).
    /// - Parameters:
    ///   - userId: The user whose favorites to display
    ///   - userName: The user's name for popup title
    ///   - userPhotoUrl: The user's profile photo URL for annotations
    ///   - favorites: The favorite places to display
    ///   - dismissProfile: Closure to dismiss the profile view
    func triggerExternalFavoritesOnMap(
        userId: String,
        userName: String?,
        userPhotoUrl: String?,
        favorites: [FavoritePlace],
        dismissProfile: @escaping () -> Void
    ) {
        mapDisplayUserId = userId
        mapDisplayUserName = userName
        mapDisplayUserPhotoUrl = userPhotoUrl
        // Convert FavoritePlace to LightweightPlace
        mapDisplayFavorites = favorites.map { fav in
            LightweightPlace(
                place_id: fav.place_id,
                name: fav.name,
                latest_review_photo: fav.latest_review_photo,
                external_place_id: nil,
                content_url: nil,
                added_by_user_id: nil,
                added_by_name: nil,
                added_by_photo_url: nil
            )
        }

        dismissProfile()

        // Defer map trigger to allow profile dismiss animation to complete before presenting new sheet
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            showExternalFavoritesOnMap = true
        }
    }

    /// Sets trip annotations to display on the main map.
    func showTripOnMap(annotations: [TripMapAnnotation], tripId: String) {
        activeTripAnnotations = annotations
        activeTripId = tripId
    }

    /// Clears trip annotations from the main map.
    func clearTripAnnotations() {
        activeTripAnnotations = []
        activeTripId = nil
    }

    /// Clears all map display state.
    func clearMapDisplayState() {
        clearTripAnnotations()
        tappedTripPlaceId = nil
        showExternalReviewsOnMap = false
        showExternalListOnMap = nil
        showExternalFavoritesOnMap = false
        mapDisplayUserId = nil
        mapDisplayUserName = nil
        mapDisplayUserPhotoUrl = nil
        mapDisplayReviews.removeAll()
        mapDisplayReviewsCount = 0
        mapDisplayFavorites.removeAll()
        mapDisplayLists.removeAll()
        mapDisplayListPlaces.removeAll()
    }

    // MARK: - Logout Cleanup

    /// Clears all user-related cached data - MUST be called on logout to prevent data leakage.
    func clearAllUserData() {
        print("🗑️ [MapDisplayCoordinatorViewModel] Clearing all user data for security")
        clearMapDisplayState()
        print("✅ [MapDisplayCoordinatorViewModel] All user data cleared")
    }
}
