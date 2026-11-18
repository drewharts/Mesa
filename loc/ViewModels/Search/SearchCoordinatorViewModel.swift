//
//  SearchCoordinatorViewModel.swift
//  loc
//
//  Created by Cursor on 11/22/25.
//  Staff Engineer: Coordinator pattern for search interactions
//

import Foundation
import UIKit

/// Coordinator ViewModel for search interactions
/// Single Responsibility: Coordinate search actions with other ViewModels
/// Staff Engineer: Does NOT own UI state (sheetHeight) - that belongs to the View
/// This prevents observation cycles that cause view recreation
@MainActor
class SearchCoordinatorViewModel {
    // MARK: - Dependencies (Weak references to prevent retain cycles)
    private weak var selectedPlaceVM: SelectedPlaceViewModel?
    private weak var userProfileNavigationViewModel: UserProfileNavigationViewModel?
    private weak var userSession: UserSession?

    // MARK: - Constants (Computed, not stored)
    var minSheetHeight: CGFloat { 250 }
    var maxSheetHeight: CGFloat { UIScreen.main.bounds.height * 0.85 }

    // MARK: - Initialization
    init(
        selectedPlaceVM: SelectedPlaceViewModel,
        userProfileNavigationViewModel: UserProfileNavigationViewModel,
        userSession: UserSession
    ) {
        self.selectedPlaceVM = selectedPlaceVM
        self.userProfileNavigationViewModel = userProfileNavigationViewModel
        self.userSession = userSession
    }
    
    // MARK: - Coordination Methods (Single Responsibility)
    
    /// Handle place selection from search
    /// Single Responsibility: Coordinate place detail presentation
    /// Returns the sheet height that should be set (starts at partial height)
    /// Note: Uses selectPlaceAndFetchDetails because the backend call populates
    /// external_reviews table (photos from around the web) as a side effect
    func handlePlaceSelection(_ detailPlace: DetailPlace) -> CGFloat {
        selectedPlaceVM?.selectPlaceAndFetchDetails(detailPlace, shouldAnimateMap: true)
        selectedPlaceVM?.isDetailSheetPresented = true

        return minSheetHeight
    }

    /// Prepares the map to animate to the selected place (call before dismiss for parallel animation).
    func prepareMapForPlace(_ detailPlace: DetailPlace) {
        selectedPlaceVM?.selectPlaceAndFetchDetails(detailPlace, shouldAnimateMap: true)
    }

    /// Whether a place detail sheet is waiting for the search sheet to finish dismissing.
    private var hasPendingPlaceDetail = false

    /// Selects a search result: dismisses the keyboard, starts the map flight, and queues the
    /// detail sheet to present only after the search sheet has fully dismissed.
    func selectPlaceFromSearch(_ detailPlace: DetailPlace) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        prepareMapForPlace(detailPlace)
        hasPendingPlaceDetail = true
    }

    /// Presents the queued place detail sheet (call from the search sheet's onDismiss).
    /// Skips it if the selection was cleared meanwhile (e.g. redirected to a city sheet).
    func presentPendingPlaceDetailIfNeeded() {
        guard hasPendingPlaceDetail else { return }
        hasPendingPlaceDetail = false
        guard selectedPlaceVM?.selectedPlace != nil else { return }
        selectedPlaceVM?.isDetailSheetPresented = true
    }

    /// Handle user selection from search
    /// Single Responsibility: Coordinate user profile navigation
    func handleUserSelection(_ profileData: ProfileData) {
        guard let currentUserId = userSession?.currentUserId else { return }
        userProfileNavigationViewModel?.selectUser(profileData, currentUserId: currentUserId)
    }
    
    /// Calculate sheet height for collapse if currently expanded
    /// Single Responsibility: Determine appropriate sheet height
    /// - Parameter currentHeight: The current sheet height
    /// - Returns: New sheet height (min if was at max, unchanged otherwise)
    func calculateCollapsedHeight(currentHeight: CGFloat) -> CGFloat {
        return currentHeight == maxSheetHeight ? minSheetHeight : currentHeight
    }
}
