//
//  SearchContainerView.swift
//  loc
//
//  Created by Cursor on 11/13/25.
//  Refactored for clean MVVM with proper callbacks
//

import SwiftUI

/// Container that displays search UI and handles search functionality
/// Single Responsibility: Manage search UI and coordinate search actions via callbacks
/// Staff Engineer: Accepts ViewModel as parameter (no recreation overhead)
struct SearchContainerView: View {
    @ObservedObject var searchViewModel: SearchViewModel  // ✅ Accept from parent
    @EnvironmentObject var appCoordinator: AppCoordinator
    @FocusState private var searchIsFocused: Bool
    @Binding var isSearchExpanded: Bool
    
    let onPlaceSelected: (DetailPlace) -> Void
    let onUserSelected: (ProfileData) -> Void
    
    init(
        searchViewModel: SearchViewModel,
        isSearchExpanded: Binding<Bool>,
        onPlaceSelected: @escaping (DetailPlace) -> Void,
        onUserSelected: @escaping (ProfileData) -> Void
    ) {
        self.searchViewModel = searchViewModel
        self._isSearchExpanded = isSearchExpanded
        self.onPlaceSelected = onPlaceSelected
        self.onUserSelected = onUserSelected
        
        // Set callback (NOT ViewModel reference)
        searchViewModel.onPlaceSelected = onPlaceSelected
    }
    
    var body: some View {
        VStack(spacing: 16) {
            searchBar
            searchResults
        }
        .onAppear {
            setupSearchView()
        }
        .onChange(of: isSearchExpanded) { oldValue, newValue in
            handleSearchExpansionChange(isExpanded: newValue)
        }
    }
    
    // MARK: - Private Methods (Single Responsibility)
    
    /// Setup search view on appearance
    private func setupSearchView() {
        // Setup search pipeline lazily (defer expensive work)
        searchViewModel.setupIfNeeded()
        // Clear search text when appearing
        searchViewModel.searchText = ""
    }
    
    /// Handle search expansion state changes
    private func handleSearchExpansionChange(isExpanded: Bool) {
        if isExpanded {
            // Ensure pipeline is setup before use
            searchViewModel.setupIfNeeded()
            
            // Delay focus to align with animation duration (0.25s)
            // This ensures the view is fully visible and stable before requesting focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak searchViewModel] in
                // CRITICAL: Check if still expanded before forcing focus
                if self.isSearchExpanded {
                    self.searchIsFocused = true
                }
            }
        } else {
            // Clear focus when collapsing
            dismissKeyboard()
        }
    }
    
    /// Dismiss keyboard immediately
    /// Single Responsibility: Handle keyboard dismissal cleanly using SwiftUI state
    private func dismissKeyboard() {
        searchIsFocused = false
        // Removed manual UIKit resignation to prevent conflicts with SwiftUI FocusState
    }
    
    private var searchBar: some View {
        TextField("Search here...", text: $searchViewModel.searchText)
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
            .foregroundStyle(Color.gray)
            .focused($searchIsFocused)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            // ✅ Removed .onTapGesture - TextField handles taps natively
            // This prevents gesture conflicts that cause "System gesture gate timed out"
    }
    
    private var searchResults: some View {
        Group {
            if !searchViewModel.searchResults.isEmpty || 
               !searchViewModel.userResults.isEmpty || 
               searchViewModel.showNoPlaceFound || 
               searchViewModel.isSearching {
                SearchResultsView(
                    placeResults: searchViewModel.searchResults,
                    userResults: searchViewModel.userResults,
                    userPhotos: searchViewModel.userPhotosSnapshot,  // ✅ Use snapshot (not reactive)
                    showNoPlaceFound: searchViewModel.showNoPlaceFound,
                    searchText: searchViewModel.searchText,
                    isSearching: searchViewModel.isSearching,
                    onSelectPlace: { suggestion in
                        // CRITICAL: Dismiss keyboard BEFORE network call to prevent keyboard from affecting sheet height
                        dismissKeyboard()
                        
                        searchViewModel.selectSuggestion(suggestion)
                        
                        // Collapse search UI after keyboard is dismissed
                        withAnimation {
                            isSearchExpanded = false
                        }
                    },
                    onSelectUser: { user in
                        // Dismiss keyboard immediately to prevent UI conflicts
                        dismissKeyboard()
                        
                        onUserSelected(user)
                        
                        withAnimation {
                            isSearchExpanded = false
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 50)
            }
        }
    }
}
