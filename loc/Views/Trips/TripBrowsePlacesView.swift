//
//  TripBrowsePlacesView.swift
//  loc
//
//  Browse tab content: searchable lists 2-column grid.
//

import SwiftUI

/// Displays the user's lists with a search bar for browsing and adding places to a trip.
struct TripBrowsePlacesView: View {
    @ObservedObject var viewModel: AddPlaceToTripViewModel

    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isLoadingInitial && !viewModel.lists.isEmpty {
                listSearchBar
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.isLoadingInitial {
                        loadingState
                    } else if viewModel.lists.isEmpty {
                        emptyState
                    } else {
                        listsGrid
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Loading State

    /// Centered spinner shown while lists are loading.
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading your lists...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Empty State

    /// Message shown when the user has no lists.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No lists yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Create lists of places to quickly add them to trips.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 32)
    }

    // MARK: - List Search Bar

    /// Search field for filtering lists by name.
    private var listSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search lists", text: $viewModel.listSearchText)
                .textFieldStyle(.plain)
            if !viewModel.listSearchText.isEmpty {
                Button {
                    viewModel.listSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    // MARK: - Lists Grid

    /// Two-column grid of the user's lists filtered by search, with NavigationLink drill-down.
    private var listsGrid: some View {
        Group {
            if viewModel.filteredLists.isEmpty {
                Text("No matching lists")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else {
                LazyVGrid(columns: listColumns, spacing: 12) {
                    ForEach(viewModel.filteredLists) { list in
                        NavigationLink {
                            TripBrowseListPlacesView(
                                listId: list.list_id,
                                listName: list.name,
                                viewModel: viewModel
                            )
                        } label: {
                            TripListTileView(
                                list: list,
                                previewPlaces: viewModel.listPreviewPlaces[list.list_id] ?? [],
                                placeColors: $viewModel.placeColors
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
