//
//  SearchOverlayView.swift
//  loc
//
//  Created by Cursor on 11/22/25.
//  Staff Engineer: Isolated search overlay to prevent recreation during parent renders
//

import SwiftUI

/// Isolated search overlay view
/// Single Responsibility: Display search UI without being affected by parent re-renders
/// MVVM: Pass-through pattern - doesn't observe what it doesn't need
struct SearchOverlayView: View {
    // MARK: - Dependencies (Pass-through only)
    let searchViewModel: SearchViewModel  // ✅ Pass-through only, no observation
    @Binding var isSearchExpanded: Bool
    
    // MARK: - Coordinator (not observed to prevent loops)
    let searchCoordinator: SearchCoordinatorViewModel
    
    // MARK: - Callbacks for state updates
    let onSheetHeightChange: (CGFloat) -> Void
    let onViewAllKeywords: () -> Void
    
    // MARK: - Animation Configuration
    // Staff Engineer: Extract animation config for consistency and maintainability
    // Duration matches iOS keyboard animation (~0.25s) for synchronized feel
    private let expansionAnimation: Animation = .easeInOut(duration: 0.25)
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            searchContent
            Spacer()
        }
        // Staff Engineer: Explicit animation tied to state value ensures smooth transitions
        // synchronized with keyboard dismiss animation
        .animation(expansionAnimation, value: isSearchExpanded)
    }
    
    // MARK: - Search Content
    // Single Responsibility: Render search container with appropriate transition
    
    @ViewBuilder
    private var searchContent: some View {
        if isSearchExpanded {
            SearchContainerView(
                searchViewModel: searchViewModel,
                isSearchExpanded: $isSearchExpanded,
                onPlaceSelected: handlePlaceSelection,
                onUserSelected: searchCoordinator.handleUserSelection,
                onViewAllKeywords: onViewAllKeywords
            )
            .id("SearchContainer")  // Stable identity prevents recreation
            .transition(.opacity)
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle place selection with sheet height update
    /// Single Responsibility: Coordinate place selection and height change
    private func handlePlaceSelection(_ detailPlace: DetailPlace) {
        let newHeight = searchCoordinator.handlePlaceSelection(detailPlace)
        onSheetHeightChange(newHeight)
    }
}
