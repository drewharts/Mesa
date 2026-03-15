//
//  TripsListView.swift
//  loc
//
//  Main trips list view - entry point from bottom nav bar
//

import SwiftUI

/// Displays the user's trips with navigation to trip detail and creation.
struct TripsListView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @StateObject private var viewModel = TripsListViewModel()
    @Environment(\.dismiss) private var dismiss

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && viewModel.trips.isEmpty {
                    loadingState
                } else if viewModel.trips.isEmpty {
                    emptyState
                } else {
                    tripsList
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: String.self) { tripId in
                TripDetailView(tripId: tripId)
                    .environmentObject(userSession)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(mapDisplayCoordinatorVM)
            }
            .fullScreenCover(isPresented: $viewModel.showCreateTrip) {
                CreateTripView { tripId in
                    // Refresh trips list, then navigate to the new trip
                    Task {
                        if let userId = userSession.currentUserId {
                            await viewModel.loadTrips(userId: userId)
                        }
                        navigationPath.append(tripId)
                    }
                }
                .environmentObject(userSession)
            }
            .task {
                if let userId = userSession.currentUserId {
                    await viewModel.loadTrips(userId: userId)
                }
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading trips...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Trips Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Plan your next adventure with friends")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.showCreateTrip = true
            } label: {
                Text("Create Trip")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(mesaCharcoal)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Trips List

    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.trips) { trip in
                    NavigationLink(value: trip.tripId) {
                        TripCardView(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            if let userId = userSession.currentUserId {
                await viewModel.loadTrips(userId: userId)
            }
        }
    }
}
