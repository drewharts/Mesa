//
//  TripBrowseListPlacesView.swift
//  loc
//
//  Drill-down view showing places within a selected list as a 2-column grid.
//  Reuses PopupPlaceCard from the profile view for consistent styling.
//

import SwiftUI

/// Displays places in a list as a 2-column grid, allowing the user to add them to the trip.
struct TripBrowseListPlacesView: View {
    let listId: String
    let listName: String
    @ObservedObject var viewModel: AddPlaceToTripViewModel

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    /// Deduplicated places matching the profile pattern in ListContentView.
    private var filteredPlaces: [LightweightPlace] {
        var seenIds = Set<String>()
        return viewModel.selectedListPlaces.filter { place in
            seenIds.insert(place.place_id).inserted
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoadingListPlaces {
                loadingState
            } else if viewModel.selectedListPlaces.isEmpty {
                emptyState
            } else {
                placesGrid
            }
        }
        .navigationTitle(listName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPlacesForList(listId: listId)
        }
    }

    // MARK: - Loading State

    /// Centered spinner shown while list places are loading.
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading places...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    /// Message shown when the list has no places.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No places in this list")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Places Grid

    /// Two-column grid using PopupPlaceCard (matching profile pattern) with add/remove overlay.
    private var placesGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(Array(filteredPlaces.enumerated()), id: \.element.id) { _, place in
                    let isInTrip = viewModel.placesInTrip.contains(place.place_id)
                    let isAdding = viewModel.isAddingPlace.contains(place.place_id)

                    ZStack(alignment: .topTrailing) {
                        PopupPlaceCard(
                            place: place,
                            preferExternalThumbnail: true,
                            onNavigate: { placeId in
                                viewModel.onViewPlaceDetail?(placeId)
                            }
                        )

                        TripPlaceActionBadge(
                            isInTrip: isInTrip,
                            isAdding: isAdding,
                            onAdd: {
                                Task { await viewModel.addSavedPlace(placeId: place.place_id) }
                            },
                            onRemove: {
                                Task { await viewModel.removeSavedPlace(placeId: place.place_id) }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
