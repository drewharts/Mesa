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
    
    var body: some View {
        VStack {
            SearchContainerView(
                searchViewModel: searchViewModel,
                isSearchExpanded: $isSearchExpanded,
                onPlaceSelected: handlePlaceSelection,
                onUserSelected: searchCoordinator.handleUserSelection
            )
            .id("SearchContainer")  // Stable identity
            .opacity(isSearchExpanded ? 1 : 0)
            .allowsHitTesting(isSearchExpanded)
            
            Spacer()
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
