//
//  TripSearchOverlay.swift
//  loc
//
//  Search overlay for finding and adding places to a trip.
//

import SwiftUI

/// Overlay for searching and selecting places to add to a trip.
struct TripSearchOverlay: View {
    let selectedDate: Date?
    let onSelectPlace: (LightweightPlace) -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel = TripSearchOverlayViewModel()

    var body: some View {
        ZStack {
            backgroundOverlay
            searchCard
        }
        .transition(.opacity)
    }

    /// Semi-transparent background.
    private var backgroundOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture {
                onDismiss()
            }
    }

    /// Main search card.
    private var searchCard: some View {
        VStack(spacing: 0) {
            headerView
            searchFieldView
            resultsList
        }
        .background(Color.white)
        .cornerRadius(20)
        .padding(.horizontal, 20)
        .padding(.vertical, 80)
    }

    /// Header with title and close button.
    private var headerView: some View {
        HStack {
            if let date = selectedDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Place")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(viewModel.formatDate(date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Text("Add Place")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }

    /// Search text field.
    private var searchFieldView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search places...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    viewModel.performSearch()
                }
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.handleSearchTextChange(newValue)
                }

            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    /// Search results list.
    private var resultsList: some View {
        Group {
            if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isSearching {
                emptyResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults, id: \.place_id) { place in
                            PlaceResultRow(place: place, onSelect: onSelectPlace)
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 400)
    }

    /// Empty results message.
    private var emptyResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.5))

            Text("No places found")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(40)
    }
}
