//
//  SearchPageViewModel.swift
//  loc
//
//  Coordinates full-screen search page state and navigation
//

import SwiftUI
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

    // MARK: - Dependencies

    private weak var userSession: UserSession?
    private weak var userProfileNavigationViewModel: UserProfileNavigationViewModel?

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
    }

    // MARK: - Setup

    /// Configure SearchViewModel callbacks for place selection
    private func setupSearchViewModelCallbacks() {
        searchViewModel.onPlaceSelected = { [weak self] place in
            self?.handlePlaceSelection(place)
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

    /// Handle user selection from search results
    func handleUserSelection(_ user: ProfileData) {
        guard let currentUserId = userSession?.currentUserId else { return }

        // Save to recent searches
        searchViewModel.saveUserSelection(user)

        // Navigate via UserProfileNavigationViewModel
        userProfileNavigationViewModel?.selectUser(user, currentUserId: currentUserId)

        // Notify callback
        onUserSelected?(user)
    }

    /// Handle view all keywords action
    func handleViewAllKeywords() {
        print("🔍 [SearchPageViewModel] handleViewAllKeywords called")
        print("   - matchedKeyword: \(searchViewModel.matchedKeyword ?? "nil")")
        print("   - currentKeywordTypes: \(searchViewModel.currentKeywordTypes)")
        print("   - onViewAllKeywords callback set: \(onViewAllKeywords != nil)")

        guard let keyword = searchViewModel.matchedKeyword else {
            print("   ❌ matchedKeyword is nil, returning early")
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
