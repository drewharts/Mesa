//
//  TripsSectionView.swift
//  loc
//
//  Profile section displaying user's trips.
//

import SwiftUI

/// Displays the trips section in the user profile.
struct TripsSectionView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showCreateTrip: Bool = false
    @State private var selectedTrip: LightweightTrip?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            tripsContent
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showCreateTrip) {
            CreateTripSheetView()
        }
        .sheet(item: $selectedTrip) { trip in
            TripPlanningView(tripId: trip.tripId)
        }
        .task {
            guard profile.tripsViewModel.trips.isEmpty else { return }
            await profile.tripsViewModel.loadUserTrips()
        }
    }

    /// Header with title and add button.
    private var headerView: some View {
        HStack {
            Text("Trips")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.black)

            Spacer()

            Button(action: { showCreateTrip = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }

    /// Content showing trips or empty state.
    @ViewBuilder
    private var tripsContent: some View {
        if profile.tripsViewModel.isLoadingTrips && profile.tripsViewModel.trips.isEmpty {
            loadingView
        } else if profile.tripsViewModel.trips.isEmpty {
            emptyStateView
        } else {
            tripsListView
        }
    }

    /// Loading indicator.
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 20)
            Spacer()
        }
    }

    /// Empty state when no trips exist.
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))

            Text("Plan your next adventure")
                .font(.subheadline)
                .foregroundColor(.gray)

            Button(action: { showCreateTrip = true }) {
                Text("Create Trip")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    /// Horizontal scrolling trips list.
    private var tripsListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(profile.tripsViewModel.trips) { trip in
                    TripCardView(trip: trip)
                        .onTapGesture {
                            selectedTrip = trip
                        }
                }
            }
        }
    }

}
