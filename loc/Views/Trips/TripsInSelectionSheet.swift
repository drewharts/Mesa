//
//  TripsInSelectionSheet.swift
//  loc
//
//  Scrollable trip list for the "Trips" tab in the save selection sheet
//

import SwiftUI

/// Displays a scrollable list of trips for saving a place as an Idea.
struct TripsInSelectionSheet: View {
    @ObservedObject var viewModel: PlaceTripSelectionViewModel
    let place: DetailPlace

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.trips.isEmpty {
                emptyStateView
            } else {
                tripListContent
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .frame(width: 20, height: 20)
            Text("Loading your trips...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var tripListContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.trips) { trip in
                TripSelectionRowView(
                    trip: trip,
                    isInTrip: viewModel.isPlaceInTrip(trip),
                    onToggle: {
                        viewModel.toggle(place: place, in: trip)
                    }
                )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            Text("No trips yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Create a trip to start saving places")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.vertical, 40)
    }
}
