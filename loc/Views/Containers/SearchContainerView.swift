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
            // ✅ Setup search pipeline lazily (staff engineer: defer expensive work)
            searchViewModel.setupIfNeeded()
            // Clear search text when appearing
            searchViewModel.searchText = ""
        }
        // ✅ Single source of truth for focus (staff engineer: no conflicts)
        .onChange(of: isSearchExpanded) { oldValue, newValue in
            if newValue {
                // Ensure pipeline is setup before use
                searchViewModel.setupIfNeeded()
                // Delay focus to ensure animation is fully complete (prevents keyboard crashes)
                // 0.35s > 0.2s animation duration
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    searchIsFocused = true
                }
            } else {
                // Clear focus when collapsing
                searchIsFocused = false
            }
        }
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
                        searchViewModel.selectSuggestion(suggestion)
                        withAnimation {
                            isSearchExpanded = false
                            searchIsFocused = false
                        }
                    },
                    onSelectUser: { user in
                        onUserSelected(user)
                        withAnimation {
                            isSearchExpanded = false
                            searchIsFocused = false
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
