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
            // Staff Engineer: Conditionally render SearchContainerView instead of hiding with opacity
            // This prevents SwiftUI's NavigationStack from restoring focus to a hidden TextField
            // when navigating back, which would cause the keyboard to reappear
            if isSearchExpanded {
                SearchContainerView(
                    searchViewModel: searchViewModel,
                    isSearchExpanded: $isSearchExpanded,
                    onPlaceSelected: handlePlaceSelection,
                    onUserSelected: searchCoordinator.handleUserSelection
                )
                .id("SearchContainer")  // Stable identity
                .transition(.opacity)
            }
            
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
