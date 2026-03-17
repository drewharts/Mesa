//
//  TripsListViewModel.swift
//  loc
//
//  ViewModel for the trips list screen
//  Single Responsibility: Fetch and manage the user's trips list
//

import Foundation

@MainActor
class TripsListViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var trips: [LightweightTrip] = []
    @Published private(set) var isLoading = false
    @Published var showCreateTrip = false
    @Published private(set) var error: String?

    // MARK: - Dependencies

    private let tripService = ServiceContainer.shared.tripService

    // MARK: - Load Trips

    /// Fetches all trips owned by or shared with the given user.
    func loadTrips(userId: String) async {
        isLoading = true
        error = nil

        do {
            trips = try await tripService.fetchUserTrips(userId: userId)
        } catch is CancellationError {
            // Expected when SwiftUI cancels the task (view disappear, refresh restart)
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Expected when the underlying URLSession request is cancelled
            return
        } catch {
            self.error = error.localizedDescription
            print("[TripsListVM] Failed to load trips: \(error)")
        }

        isLoading = false
    }

    /// Deletes a trip and removes it from the local list.
    func deleteTrip(tripId: String) async {
        do {
            try await tripService.deleteTrip(tripId: tripId)
            trips.removeAll { $0.tripId == tripId }
        } catch {
            self.error = error.localizedDescription
            print("[TripsListVM] Failed to delete trip: \(error)")
        }
    }
}
