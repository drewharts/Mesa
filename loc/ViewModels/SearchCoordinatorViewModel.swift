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
@MainActor
class SearchCoordinatorViewModel: ObservableObject {
    // MARK: - Dependencies (Weak references to prevent retain cycles)
    private weak var selectedPlaceVM: SelectedPlaceViewModel?
    private weak var userProfileViewModel: UserProfileViewModel?
    private weak var userSession: UserSession?
    
    // MARK: - Published State
    @Published var sheetHeight: CGFloat
    
    // MARK: - Constants
    private let minSheetHeight: CGFloat = 250
    private var maxSheetHeight: CGFloat { UIScreen.main.bounds.height * 0.85 }
    
    // MARK: - Computed Properties
    var minHeight: CGFloat { minSheetHeight }
    var maxHeight: CGFloat { maxSheetHeight }
    
    // MARK: - Initialization
    init(
        selectedPlaceVM: SelectedPlaceViewModel,
        userProfileViewModel: UserProfileViewModel,
        userSession: UserSession
    ) {
        self.selectedPlaceVM = selectedPlaceVM
        self.userProfileViewModel = userProfileViewModel
        self.userSession = userSession
        self.sheetHeight = UIScreen.main.bounds.height * 0.85
    }
    
    // MARK: - Coordination Methods (Single Responsibility)
    
    /// Handle place selection from search
    /// Single Responsibility: Coordinate place detail presentation
    func handlePlaceSelection(_ detailPlace: DetailPlace) {
        selectedPlaceVM?.selectPlaceAndFetchDetails(detailPlace, shouldAnimateMap: true)
        sheetHeight = maxSheetHeight
        selectedPlaceVM?.isDetailSheetPresented = true
    }
    
    /// Handle user selection from search
    /// Single Responsibility: Coordinate user profile navigation
    func handleUserSelection(_ profileData: ProfileData) {
        guard let currentUserId = userSession?.currentUserId else { return }
        userProfileViewModel?.selectUser(profileData, currentUserId: currentUserId)
    }
    
    /// Reset sheet height to maximum
    /// Single Responsibility: Manage sheet height state
    func resetSheetToMaxHeight() {
        sheetHeight = maxSheetHeight
    }
    
    /// Collapse sheet to minimum height if at maximum
    /// Single Responsibility: Manage sheet collapse behavior
    func collapseSheetIfExpanded() {
        if sheetHeight == maxSheetHeight {
            sheetHeight = minSheetHeight
        }
    }
}
