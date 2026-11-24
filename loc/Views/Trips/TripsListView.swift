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

    /// False when the list is the root of the Trips tab (there is nothing to close).
    private let showsCloseButton: Bool

    /// True while the hosting tab is the visible one; a false-to-true change reloads trips.
    private let isActive: Bool

    @Environment(\.scenePhase) private var scenePhase

    /// Creates the trips list; pass `showsCloseButton: false` when hosted as a tab.
    init(showsCloseButton: Bool = true, isActive: Bool = true) {
        self.showsCloseButton = showsCloseButton
        self.isActive = isActive
    }

    var body: some View { analyticsBody.analyticsScreen("Trips") }

    @ViewBuilder private var analyticsBody: some View {
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
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
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
            .onReceive(NotificationManager.shared.$pendingTripId.compactMap { $0 }) { tripId in
                // A trip push tapped while this tab already exists (the .task below only runs once).
                NotificationManager.shared.pendingTripId = nil
                navigationPath.append(tripId)
            }
            .onChange(of: isActive) { _, active in
                guard active, let userId = userSession.currentUserId else { return }
                Task { await viewModel.loadTrips(userId: userId) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, isActive, let userId = userSession.currentUserId else { return }
                Task { await viewModel.loadTrips(userId: userId) }
            }
            .task {
                if let userId = userSession.currentUserId {
                    await viewModel.loadTrips(userId: userId)
                }
                // Auto-navigate to trip from push notification (after data loads)
                if let tripId = NotificationManager.shared.pendingTripId {
                    NotificationManager.shared.pendingTripId = nil
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    navigationPath.append(tripId)
                }
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        TripsListSkeletonView()
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
                NewTripTileView { viewModel.showCreateTrip = true }
                ForEach(viewModel.currentTrips) { trip in
                    tripLink(trip)
                }
                if !viewModel.pastTrips.isEmpty {
                    pastTripsHeader
                    if viewModel.isPastExpanded {
                        ForEach(viewModel.pastTrips) { trip in
                            tripLink(trip)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func tripLink(_ trip: LightweightTrip) -> some View {
        NavigationLink(value: trip.tripId) {
            TripCardView(trip: trip)
        }
        .buttonStyle(.plain)
    }

    private var pastTripsHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.togglePastExpanded() }
        } label: {
            HStack {
                Text("Past trips (\(viewModel.pastTrips.count))")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(viewModel.isPastExpanded ? 180 : 0))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(viewModel.isPastExpanded ? "Collapse past trips" : "Expand past trips")
    }
}
