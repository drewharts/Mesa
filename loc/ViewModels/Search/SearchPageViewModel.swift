//
//  SearchPageViewModel.swift
//  loc
//
//  Coordinates full-screen search page state and navigation
//

import SwiftUI
import Combine
import CoreLocation
import MapKit

/// ViewModel for the full-screen search page
/// Single Responsibility: Coordinate search page state and navigation callbacks
@MainActor
class SearchPageViewModel: ObservableObject {
    // MARK: - Child ViewModel

    let searchViewModel: SearchViewModel

    // MARK: - Navigation Callbacks

    var onDismiss: (() -> Void)?
    var onPlaceSelected: ((DetailPlace) -> Void)?
    var onUserSelected: ((ProfileData) -> Void)?
    var onViewAllKeywords: ((String, [String]) -> Void)?
    var onCoordinateSelected: ((CLLocationCoordinate2D) -> Void)?
    var onCitySelected: ((CitySearchResult) -> Void)?

    // MARK: - Dependencies

    private weak var userSession: UserSession?
    private weak var userProfileNavigationViewModel: UserProfileNavigationViewModel?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        searchViewModel: SearchViewModel,
        userSession: UserSession,
        userProfileNavigationViewModel: UserProfileNavigationViewModel
    ) {
        self.searchViewModel = searchViewModel
        self.userSession = userSession
        self.userProfileNavigationViewModel = userProfileNavigationViewModel

        setupSearchViewModelCallbacks()
        forwardChildChanges()
    }

    // MARK: - Setup

    /// Forward objectWillChange from child SearchViewModel so parent view re-renders
    private func forwardChildChanges() {
        searchViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Configure SearchViewModel callbacks for place and city selection
    private func setupSearchViewModelCallbacks() {
        searchViewModel.onPlaceSelected = { [weak self] place in
            self?.handlePlaceSelection(place)
        }
        searchViewModel.onCitySelected = { [weak self] city in
            self?.handleCitySelection(city)
        }
    }

    // MARK: - Public Methods

    /// Dismiss the search page
    func dismiss() {
        onDismiss?()
    }

    /// Handle place selection from search results
    func handlePlaceSelection(_ place: DetailPlace) {
        onPlaceSelected?(place)
    }

    /// Handle user selection from search results — dismisses search and navigates via MainView
    func handleUserSelection(_ user: ProfileData) {
        guard let currentUserId = userSession?.currentUserId else { return }

        // Save to recent searches
        searchViewModel.saveUserSelection(user)

        // Dismiss search sheet for all user selections
        onDismiss?()

        if user.id == currentUserId {
            // Own profile: selectUser sets shouldNavigateToOwnProfile, fullScreenCover handles it
            userProfileNavigationViewModel?.selectUser(user, currentUserId: currentUserId, shouldPresent: false)
        } else {
            // External user: navigate in MainView after sheet dismissal (PlaceSavers pattern)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.userProfileNavigationViewModel?.selectUser(user, currentUserId: currentUserId)
            }
        }

        // Notify callback
        onUserSelected?(user)
    }

    /// Handle coordinate selection from search results
    func handleCoordinateSelection(_ coordinate: CLLocationCoordinate2D) {
        onCoordinateSelected?(coordinate)
    }

    /// Handle city selection from search results — dismisses search and presents city sheet.
    func handleCitySelection(_ city: CitySearchResult) {
        onDismiss?()
        onCitySelected?(city)
    }

    /// Handle view all keywords action
    func handleViewAllKeywords() {
        guard let keyword = searchViewModel.matchedKeyword else {
            return
        }
        onViewAllKeywords?(keyword, searchViewModel.currentKeywordTypes)
        print("   ✅ Called onViewAllKeywords callback")
    }

    /// Set the current map region for viewport-based searches
    func setMapRegion(_ region: MKCoordinateRegion?) {
        searchViewModel.currentMapRegion = region
    }
}
