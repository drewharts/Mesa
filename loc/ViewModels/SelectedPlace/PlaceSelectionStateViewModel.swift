//
//  PlaceSelectionStateViewModel.swift
//  loc
//
//  Manages place selection state, sheet presentation, and navigation.
//  Single Responsibility: Only handles selection state and sheet/navigation coordination.
//

import Foundation
import CoreLocation

@MainActor
class PlaceSelectionStateViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The currently selected place.
    @Published var selectedPlace: DetailPlace?

    /// Whether the detail sheet is presented.
    @Published var isDetailSheetPresented: Bool = false

    /// Whether to allow auto-presentation of the detail sheet.
    @Published var allowAutoPresent: Bool = true

    /// Whether the map should animate to the selected place.
    @Published var shouldAnimateMapToPlace: Bool = false

    /// Preserved place for navigation restoration.
    @Published var preservedPlaceForNavigation: DetailPlace?

    // MARK: - Private State

    /// Flag to prevent didSet from re-triggering during programmatic updates.
    private(set) var isUpdatingPlaceDetails = false

    /// Flag indicating a fresh details fetch is in progress.
    private(set) var isFetchingFreshDetails = false

    // MARK: - Callbacks

    /// Called when a new place is selected and needs setup (posts loading, etc.).
    var onPlaceSelected: ((DetailPlace) -> Void)?

    /// Called when fresh details need to be fetched for a place.
    var onFetchFreshDetails: ((DetailPlace) -> Void)?

    // MARK: - Public Methods

    /// Selects a place that already has complete data.
    /// Use this when selecting from map annotations where data was already fetched from backend.
    func selectPlace(_ place: DetailPlace, shouldAnimateMap: Bool = true) {
        // Set selectedPlace FIRST so coordinate is available when onChange observer fires
        selectedPlace = place
        // Only set animation flag to true, never reset to false (avoids race conditions with concurrent callers)
        if shouldAnimateMap {
            let hasValidCoordinates = place.coordinate?.isValidForNavigation == true
            if hasValidCoordinates { shouldAnimateMapToPlace = true }
        }
        onPlaceSelected?(place)
    }

    /// Selects a place and triggers a fresh details fetch from backend.
    /// Use this when selecting from search results or other sources with potentially stale data.
    func selectPlaceAndFetchDetails(_ place: DetailPlace, shouldAnimateMap: Bool = true) {
        // Set selectedPlace FIRST so coordinate is available when onChange observer fires
        selectedPlace = place
        isFetchingFreshDetails = true
        // Only set animation flag to true, never reset to false (avoids race conditions with concurrent callers)
        if shouldAnimateMap {
            let hasValidCoordinates = place.coordinate?.isValidForNavigation == true
            if hasValidCoordinates { shouldAnimateMapToPlace = true }
        }
        onPlaceSelected?(place)
        onFetchFreshDetails?(place)
    }

    /// Updates the selected place with fresh data without triggering onPlaceSelected.
    func updatePlaceDetails(_ place: DetailPlace) {
        isUpdatingPlaceDetails = true
        selectedPlace = place
        isUpdatingPlaceDetails = false
    }

    /// Marks the fresh details fetch as complete.
    func markFetchComplete() {
        isFetchingFreshDetails = false
    }

    /// Presents the detail sheet if allowed.
    func presentDetailSheet() {
        if allowAutoPresent && !isDetailSheetPresented {
            isDetailSheetPresented = true
        }
    }

    /// Forces presentation of the detail sheet.
    func forcePresentDetailSheet() {
        isDetailSheetPresented = true
    }

    /// Dismisses the detail sheet.
    func dismissDetailSheet() {
        isDetailSheetPresented = false
    }

    // MARK: - State Preservation

    /// Preserves current place state before navigating to user profile.
    func preserveStateForNavigation() {
        preservedPlaceForNavigation = selectedPlace
    }

    /// Restores place state after returning from user profile navigation.
    func restoreStateAfterNavigation() {
        if let preserved = preservedPlaceForNavigation {
            selectedPlace = preserved
            isDetailSheetPresented = true
            preservedPlaceForNavigation = nil
        }
    }

    /// Clears preserved state.
    func clearPreservedState() {
        preservedPlaceForNavigation = nil
    }

    // MARK: - Cleanup

    /// Clears all selection state.
    func clearAllState() {
        selectedPlace = nil
        isDetailSheetPresented = false
        allowAutoPresent = true
        shouldAnimateMapToPlace = false
        preservedPlaceForNavigation = nil
        isUpdatingPlaceDetails = false
        isFetchingFreshDetails = false
    }
}
