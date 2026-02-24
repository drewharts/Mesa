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
            if viewModel.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    tripMenu
                }
            }
        }
        .navigationDestination(item: $viewModel.selectedDayForDetail) { dayIndex in
            TripDayDetailView(viewModel: viewModel, dayIndex: dayIndex)
        }
        .onChange(of: viewModel.selectedDayForDetail) { old, new in
            if old != nil && new == nil {
                Task { await viewModel.loadTrip() }
            }
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
            await viewModel.loadTrip()
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
