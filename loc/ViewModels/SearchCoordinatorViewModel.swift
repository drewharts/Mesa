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
