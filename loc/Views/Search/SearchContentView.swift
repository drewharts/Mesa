//
//  SearchContentView.swift
//  loc
//
//  SMART Component: Displays search content (recent searches or results)
//

import SwiftUI
import CoreLocation

/// SMART Component: Displays search content based on current state
/// Single Responsibility: Coordinate display of recent searches vs search results
struct SearchContentView: View {
    // MARK: - ViewModel

    @ObservedObject var searchViewModel: SearchViewModel

    // MARK: - Callbacks

    let onSelectPlace: (DetailPlace) -> Void
    let onSelectUser: (ProfileData) -> Void
    let onViewAllKeywords: () -> Void
    let onSelectCoordinate: (CLLocationCoordinate2D) -> Void

    // MARK: - Body

    var body: some View {
        Group {
            if shouldShowRecentSearches {
                recentSearchesSection
            } else if shouldShowSearchResults {
                searchResultsSection
            } else {
                emptyStateView
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
        searchViewModel.parsedCoordinate != nil ||
        !searchViewModel.searchResults.isEmpty ||
        !searchViewModel.userResults.isEmpty ||
        !searchViewModel.keywordResults.isEmpty ||
        !searchViewModel.aiSuggestionsViewModel.suggestions.isEmpty ||
        searchViewModel.aiSuggestionsViewModel.isLoading ||
        searchViewModel.showNoPlaceFound ||
        searchViewModel.isSearching
    }

    // MARK: - Recent Searches Section

    private var recentSearchesSection: some View {
        RecentSearchesView(
            selections: searchViewModel.recentSelections,
            userPhotos: searchViewModel.userPhotosSnapshot,
            onSelectPlace: { placeId in
                searchViewModel.selectRecentPlace(id: placeId)
            },
            onSelectUser: { userId in
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
                    onSelectUser(user)
                }
            },
            onClearAll: {
                searchViewModel.clearRecentSearches()
            }
        )
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        VStack(spacing: 0) {
            coordinateRow

            SearchResultsView(
                placeResults: searchViewModel.searchResults,
                userResults: searchViewModel.userResults,
                userPhotos: searchViewModel.userPhotosSnapshot,
                showNoPlaceFound: searchViewModel.showNoPlaceFound,
                searchText: searchViewModel.searchText,
                isSearching: searchViewModel.isSearching,
                onSelectPlace: { suggestion in
                    searchViewModel.selectSuggestion(suggestion)
                },
                onSelectUser: { user in
                    searchViewModel.saveUserSelection(user)
                    onSelectUser(user)
                },
                keywordResults: searchViewModel.keywordResults,
                matchedKeyword: searchViewModel.matchedKeyword,
                hasMoreKeywordResults: searchViewModel.hasMoreKeywordResults,
                isLoadingMoreKeywords: searchViewModel.isLoadingMoreKeywords,
                onSelectKeywordPlace: { place in
                    onSelectPlace(place)
                },
                onLoadMoreKeywords: {
                    searchViewModel.loadMoreKeywordResults()
                },
                onViewAllKeywords: onViewAllKeywords,
                aiSuggestions: searchViewModel.aiSuggestionsViewModel.suggestions,
                isAILoading: searchViewModel.aiSuggestionsViewModel.isLoading,
                aiError: searchViewModel.aiSuggestionsViewModel.error,
                onSelectAIPlace: { place in
                    searchViewModel.saveAIPlaceSelection(place)
                    onSelectPlace(place)
                }
            )
        }
    }

    // MARK: - Coordinate Row

    /// Row displayed when the user types GPS coordinates in the search bar
    @ViewBuilder
    private var coordinateRow: some View {
        if let coordinate = searchViewModel.parsedCoordinate {
            VStack(spacing: 0) {
                Button {
                    onSelectCoordinate(coordinate)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Go to coordinate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("Search for places and users")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}
