//
//  TripDetailView.swift
//  loc
//
//  Main trip detail view - header, day selector, itinerary, and actions
//

import SwiftUI

/// Displays a trip's full details with day-by-day itinerary.
struct TripDetailView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @StateObject private var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(tripId: String) {
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(tripId: tripId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.trip == nil {
                ProgressView("Loading trip...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let trip = viewModel.trip {
                TripDetailContentView(trip: trip, viewModel: viewModel)
            } else if viewModel.error != nil {
                errorContent
            }
        }
        .navigationTitle(viewModel.trip?.name ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if viewModel.hasPlacesWithCoordinates {
                        mapButton
                    }
                    if viewModel.canEdit {
                        tripMenu
                    }
                }
            }
        }
        .navigationDestination(item: $viewModel.selectedDayForDetail) { dayIndex in
            TripDayDetailView(viewModel: viewModel, dayIndex: dayIndex)
        }
        .navigationDestination(item: $viewModel.selectedPlaceIdForDetail) { placeId in
            PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
        }
        .onChange(of: mapDisplayCoordinatorVM.tappedTripPlaceId) { _, placeId in
            viewModel.handleMapPlaceTap(placeId)
        }
        .onChange(of: viewModel.selectedDayForDetail) { old, new in
            Task { await viewModel.handleDayFilterChange(old: old, new: new) }
        }
        .sheet(isPresented: $viewModel.showCollaboratorsSheet) {
            if let userId = userSession.currentUserId {
                ManageTripCollaboratorsSheet(
                    tripId: viewModel.tripId,
                    currentUserId: userId
                )
            }
        }
        .task {
            viewModel.setMapCoordinator(mapDisplayCoordinatorVM)
            await viewModel.loadTripAndShowAnnotations()
        }
        .onDisappear {
            guard viewModel.selectedDayForDetail == nil else { return }
            viewModel.clearMapAnnotations()
        }
    }

    // MARK: - Map Button

    /// Re-fits the map camera to the currently visible trip annotations.
    private var mapButton: some View {
        Button {
            viewModel.fitMapToCurrentAnnotations()
        } label: {
            Image(systemName: "map")
        }
    }

    // MARK: - Trip Menu

    private var tripMenu: some View {
        Menu {
            Button {
                viewModel.showCollaboratorsSheet = true
            } label: {
                Label("Manage People", systemImage: "person.badge.plus")
            }
            if viewModel.isOwner {
                Button(role: .destructive) {
                    Task {
                        try? await viewModel.deleteTrip()
                        dismiss()
                    }
                } label: {
                    Label("Delete Trip", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Error Content

    private var errorContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(viewModel.error ?? "Something went wrong")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await viewModel.loadTrip() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
