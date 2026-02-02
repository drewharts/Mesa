//
//  TripPlanningView.swift
//  loc
//
//  Main trip planning interface showing days and places.
//

import SwiftUI

/// Main view for planning a trip with drag-and-drop place management.
struct TripPlanningView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: TripPlanningViewModel
    @State private var showDeleteConfirmation: Bool = false

    /// Initializes the view with a trip ID.
    init(tripId: String) {
        self._viewModel = StateObject(wrappedValue: TripPlanningViewModel(tripId: tripId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                contentView
                searchOverlayView
            }
            .navigationTitle(viewModel.trip?.name ?? "Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Delete Trip?", isPresented: $showDeleteConfirmation) {
                deleteAlertButtons
            } message: {
                Text("This will delete the trip and all its places. This action cannot be undone.")
            }
            .task {
                await viewModel.loadTrip()
            }
        }
    }

    /// Main content based on loading state.
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else if let trip = viewModel.trip {
            tripScrollView(trip: trip)
        } else {
            errorView
        }
    }

    /// Loading indicator view.
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading trip...")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
    }

    /// Error state view with retry option.
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(viewModel.errorMessage ?? "Failed to load trip")
                .font(.headline)

            Button("Try Again") {
                Task { await viewModel.loadTrip() }
            }
        }
    }

    /// Scrollable trip content.
    private func tripScrollView(trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                TripPlanningHeaderView(
                    dateRange: viewModel.formattedDateRange(),
                    numberOfDays: trip.numberOfDays,
                    totalPlaces: viewModel.totalPlaceCount
                )

                ForEach(viewModel.allTripDates, id: \.self) { date in
                    TripDayView(
                        date: date,
                        dayNumber: viewModel.dayNumber(for: date),
                        places: viewModel.places(for: date),
                        onAddPlace: { viewModel.openSearchForDay(date) },
                        onRemovePlace: { placeId in
                            Task { await viewModel.removePlace(placeId: placeId, from: date) }
                        },
                        onReorderPlaces: { from, to in
                            Task { await viewModel.reorderPlaces(in: date, from: from, to: to) }
                        }
                    )
                }
            }
            .padding(.bottom, 40)
        }
    }

    /// Search overlay for adding places.
    @ViewBuilder
    private var searchOverlayView: some View {
        if viewModel.showSearchOverlay {
            TripSearchOverlay(
                selectedDate: viewModel.selectedDayDate,
                onSelectPlace: { place in
                    Task { await viewModel.addPlace(place) }
                },
                onDismiss: { viewModel.closeSearch() }
            )
        }
    }

    /// Toolbar items.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    Label("Delete Trip", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    /// Alert buttons for delete confirmation.
    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
            Task {
                if await profile.tripsViewModel.deleteTrip(tripId: viewModel.tripId) {
                    dismiss()
                }
            }
        }
    }
}
