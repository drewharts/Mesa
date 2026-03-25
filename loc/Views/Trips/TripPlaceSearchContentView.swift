//
//  TripPlaceSearchContentView.swift
//  loc
//
//  Search tab content: search bar and results list for adding places to a trip.
//

import SwiftUI

/// Provides place search functionality for adding new places to a trip.
struct TripPlaceSearchContentView: View {
    @ObservedObject var viewModel: AddPlaceToTripViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchField
            searchResultsList
        }
    }

    // MARK: - Search Field

    /// Text field with magnifying glass icon, clear button, and search spinner.
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search places...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.search(query: newValue)
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Search Results

    /// List of search results with tap-to-add functionality.
    private var searchResultsList: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }

            if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isSearching {
                Text("No places found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.searchResults, id: \.id) { suggestion in
                    TripSearchResultRowView(
                        suggestion: suggestion,
                        isAdding: viewModel.isAddingPlace.contains(suggestion.id),
                        isInTrip: viewModel.addedSuggestionIds.contains(suggestion.id),
                        isResolving: viewModel.isResolvingSuggestion == suggestion.id,
                        onNavigate: { Task { await viewModel.resolveAndNavigateToPlaceDetail(suggestion: suggestion) } },
                        onAdd: { Task { await viewModel.searchAndAddPlace(suggestion: suggestion) } },
                        onRemove: { Task { await viewModel.searchAndAddPlace(suggestion: suggestion) } }
                    )
                }
            }
        }
        .listStyle(.plain)
    }
}
