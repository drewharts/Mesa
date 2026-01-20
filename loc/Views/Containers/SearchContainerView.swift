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
    @FocusState private var searchIsFocused: Bool
    @Binding var isSearchExpanded: Bool
    
    let onPlaceSelected: (DetailPlace) -> Void
    let onUserSelected: (ProfileData) -> Void
    let onViewAllKeywords: () -> Void

    init(
        searchViewModel: SearchViewModel,
        isSearchExpanded: Binding<Bool>,
        onPlaceSelected: @escaping (DetailPlace) -> Void,
        onUserSelected: @escaping (ProfileData) -> Void,
        onViewAllKeywords: @escaping () -> Void
    ) {
        self.searchViewModel = searchViewModel
        self._isSearchExpanded = isSearchExpanded
        self.onPlaceSelected = onPlaceSelected
        self.onUserSelected = onUserSelected
        self.onViewAllKeywords = onViewAllKeywords

        // Set callback (NOT ViewModel reference)
        searchViewModel.onPlaceSelected = onPlaceSelected
    }
    
    var body: some View {
        VStack(spacing: 16) {
            searchBar
            searchResults
        }
        .onAppear {
            // Setup pipeline only once on first appearance
            searchViewModel.setupIfNeeded()
            // Set initial focus state when view appears (onChange won't fire on initial render)
            if isSearchExpanded {
                handleSearchExpansionChange(isExpanded: true)
            }
        }
        .onChange(of: isSearchExpanded) { oldValue, newValue in
            handleSearchExpansionChange(isExpanded: newValue)
        }
    }
    
    /// Handle search expansion state changes
    private func handleSearchExpansionChange(isExpanded: Bool) {
        if isExpanded {
            // Clear search text when opening
            searchViewModel.searchText = ""
            // Focus immediately - no delay needed with proper isolation
            searchIsFocused = true
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
        HStack(spacing: 8) {
            TextField("Search here...", text: $searchViewModel.searchText)
                .foregroundStyle(Color.gray)
                .focused($searchIsFocused)
            
            // Cancel button - dismisses search and keyboard
            Button(action: {
                dismissKeyboard()
                withAnimation {
                    isSearchExpanded = false
                }
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var searchResults: some View {
        Group {
            if shouldShowRecentSearches {
                recentSearchesSection
            } else if shouldShowSearchResults {
                searchResultsSection
            }
        }
    }
    
    // MARK: - View State Helpers
    
    private var shouldShowRecentSearches: Bool {
        searchViewModel.searchText.isEmpty &&
        !searchViewModel.recentSelections.isEmpty &&
        !searchViewModel.isSearching
    }
    
    private var shouldShowSearchResults: Bool {
        !searchViewModel.searchResults.isEmpty ||
        !searchViewModel.userResults.isEmpty ||
        !searchViewModel.keywordResults.isEmpty ||
        searchViewModel.showNoPlaceFound ||
        searchViewModel.isSearching
    }
    
    // MARK: - Recent Selections Section
    
    private var recentSearchesSection: some View {
        RecentSearchesView(
            selections: searchViewModel.recentSelections,
            userPhotos: searchViewModel.userPhotosSnapshot,
            onSelectPlace: { placeId in
                dismissKeyboard()
                searchViewModel.selectRecentPlace(id: placeId)
                withAnimation {
                    isSearchExpanded = false
                }
            },
            onSelectUser: { userId in
                dismissKeyboard()
                // Reconstruct minimal ProfileData from recent selection for navigation
                if let selection = searchViewModel.recentSelections.first(where: {
                    if case .user(let id, _, _) = $0 { return id == userId }
                    return false
                }), case .user(let id, let name, let photoURLString) = selection {
                    let nameParts = name.components(separatedBy: " ")
                    let user = ProfileData(
                        id: id,
                        firstName: nameParts.first ?? name,
                        lastName: nameParts.dropFirst().joined(separator: " "),
                        email: "",
                        profilePhotoURL: photoURLString.flatMap { URL(string: $0) },
                        phoneNumber: "",
                        fullNameLower: name.lowercased(),
                        fullName: name,
                        fcmToken: nil,
                        firebaseUid: nil,
                        supabaseUid: nil
                    )
                    onUserSelected(user)
                }
                withAnimation {
                    isSearchExpanded = false
                }
            },
            onClearAll: {
                searchViewModel.clearRecentSearches()
            }
        )
        .padding(.top, 10)
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        SearchResultsView(
            placeResults: searchViewModel.searchResults,
            userResults: searchViewModel.userResults,
            userPhotos: searchViewModel.userPhotosSnapshot,
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

                // Save user to recent selections
                searchViewModel.saveUserSelection(user)

                onUserSelected(user)

                withAnimation {
                    isSearchExpanded = false
                }
            },
            keywordResults: searchViewModel.keywordResults,
            matchedKeyword: searchViewModel.matchedKeyword,
            hasMoreKeywordResults: searchViewModel.hasMoreKeywordResults,
            isLoadingMoreKeywords: searchViewModel.isLoadingMoreKeywords,
            onSelectKeywordPlace: { place in
                // Dismiss keyboard before navigating
                dismissKeyboard()

                // Navigate to the selected place
                onPlaceSelected(place)

                withAnimation {
                    isSearchExpanded = false
                }
            },
            onLoadMoreKeywords: {
                searchViewModel.loadMoreKeywordResults()
            },
            onViewAllKeywords: {
                // Dismiss keyboard and collapse search before triggering popup
                dismissKeyboard()
                withAnimation {
                    isSearchExpanded = false
                }
                onViewAllKeywords()
            }
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 50)
    }
}
