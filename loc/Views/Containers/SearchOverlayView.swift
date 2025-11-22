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
/// MVVM: Observes only what it needs, preventing cascade updates
struct SearchOverlayView: View {
    // MARK: - Dependencies
    @ObservedObject var searchViewModel: SearchViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    // MARK: - Coordinator (not observed to prevent loops)
    let searchCoordinator: SearchCoordinatorViewModel
    
    // MARK: - Callbacks for state updates
    let onSheetHeightChange: (CGFloat) -> Void
    
    var body: some View {
        VStack {
            SearchContainerView(
                searchViewModel: searchViewModel,
                isSearchExpanded: $appCoordinator.isSearchExpanded,
                onPlaceSelected: handlePlaceSelection,
                onUserSelected: searchCoordinator.handleUserSelection
            )
            .id("SearchContainer")  // Stable identity
            .opacity(appCoordinator.isSearchExpanded ? 1 : 0)
            .allowsHitTesting(appCoordinator.isSearchExpanded)
            
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
