//
//  PlaceTripSelectionViewModel.swift
//  loc
//
//  ViewModel for the "Trips" tab in the place save selection sheet
//  Single Responsibility: Manage trip selection state for adding places to trips as Ideas
//

import Foundation

@MainActor
class PlaceTripSelectionViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var trips: [LightweightTrip] = []
    @Published private(set) var isLoading = false
    @Published var placeMembership: [String: Bool] = [:]

    // MARK: - Dependencies

    private let tripService = ServiceContainer.shared.tripService
    private let authService = ServiceContainer.shared.authService

    // MARK: - Load Trips

    /// Fetches user's trips and checks which ones contain the given place.
    func loadTrips(for place: DetailPlace) async {
        guard let userId = authService.currentUserId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            trips = try await tripService.fetchUserTrips(userId: userId)

            if !trips.isEmpty {
                let tripIds = trips.map(\.tripId)
                placeMembership = try await tripService.fetchPlaceTripMembership(
                    placeId: place.id.uuidString,
                    tripIds: tripIds
                )
            }
        } catch {
            print("[PlaceTripSelectionVM] Failed to load trips: \(error)")
        }
    }

    // MARK: - Toggle

    /// Adds or removes a place from a trip as an Idea (dayIndex = -1).
    func toggle(place: DetailPlace, in trip: LightweightTrip) {
        guard let userId = authService.currentUserId else { return }

        let wasInTrip = placeMembership[trip.tripId] ?? false

        // Optimistic update
        placeMembership[trip.tripId] = !wasInTrip

        Task {
            do {
                if wasInTrip {
                    try await tripService.removePlaceFromTrip(
                        tripId: trip.tripId,
                        placeId: place.id.uuidString
                    )
                } else {
                    try await tripService.addPlaceAsIdea(
                        tripId: trip.tripId,
                        placeId: place.id.uuidString,
                        addedBy: userId
                    )
                }
            } catch {
                // Revert on failure
                placeMembership[trip.tripId] = wasInTrip
                print("[PlaceTripSelectionVM] Toggle failed: \(error)")
            }
        }
    }

    // MARK: - Query

    /// Returns whether the place is currently in the given trip.
    func isPlaceInTrip(_ trip: LightweightTrip) -> Bool {
        placeMembership[trip.tripId] ?? false
    }
}
