//
//  TripsLoadingViewModel.swift
//  loc
//
//  Child ViewModel for trip loading states and operations.
//

import SwiftUI

/// Manages trip loading operations and states.
@MainActor
class TripsLoadingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Loading initial trips.
    @Published var isLoadingTrips: Bool = false

    /// Loading a specific trip's details.
    @Published var isLoadingTripDetails: Bool = false

    /// Loading places for a trip.
    @Published var isLoadingPlaces: Bool = false

    /// Error message for display.
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private weak var userSession: UserSession?
    private weak var dataViewModel: TripsDataViewModel?
    private let tripService = TripService.shared

    // MARK: - Initialization

    /// Initializes with required dependencies.
    init(userSession: UserSession, dataViewModel: TripsDataViewModel) {
        self.userSession = userSession
        self.dataViewModel = dataViewModel
    }

    // MARK: - Load User Trips

    /// Loads all trips for the current user.
    func loadUserTrips() async {
        guard let userId = userSession?.currentUserId else {
            errorMessage = "No user session"
            return
        }

        guard !isLoadingTrips else { return }
        isLoadingTrips = true
        errorMessage = nil

        do {
            let trips = try await tripService.fetchUserTrips(userId: userId)
            dataViewModel?.setTrips(trips)
        } catch {
            print("❌ [TripsLoadingViewModel] Failed to load trips: \(error)")
            errorMessage = "Failed to load trips"
        }

        isLoadingTrips = false
    }

    // MARK: - Load Trip Details

    /// Loads a specific trip's full details.
    func loadTripDetails(tripId: String) async {
        guard !isLoadingTripDetails else { return }
        isLoadingTripDetails = true
        errorMessage = nil

        do {
            let trip = try await tripService.fetchTrip(tripId: tripId)
            dataViewModel?.currentTrip = trip
        } catch {
            print("❌ [TripsLoadingViewModel] Failed to load trip details: \(error)")
            errorMessage = "Failed to load trip details"
        }

        isLoadingTripDetails = false
    }

    // MARK: - Load Trip Places

    /// Loads places for a trip grouped by day.
    func loadTripPlaces(tripId: String) async {
        guard !isLoadingPlaces else { return }
        isLoadingPlaces = true
        errorMessage = nil

        do {
            var dayPlaces = try await tripService.fetchTripPlacesByDay(tripId: tripId)

            // Fetch place details for each place ID
            let allPlaceIds = dayPlaces.flatMap { $0.places.map { $0.placeId } }
            let uniquePlaceIds = Array(Set(allPlaceIds))

            if !uniquePlaceIds.isEmpty {
                let places = try await fetchPlaceDetails(placeIds: uniquePlaceIds)
                dataViewModel?.cachePlaces(places)

                // Attach place details to items
                for dayIndex in dayPlaces.indices {
                    for placeIndex in dayPlaces[dayIndex].places.indices {
                        let placeId = dayPlaces[dayIndex].places[placeIndex].placeId
                        if let place = dataViewModel?.getCachedPlace(placeId: placeId) {
                            let tripPlace = dayPlaces[dayIndex].places[placeIndex].tripPlace
                            dayPlaces[dayIndex].places[placeIndex] = TripPlaceItem(tripPlace: tripPlace, place: place)
                        }
                    }
                }
            }

            dataViewModel?.setDayPlaces(dayPlaces)
        } catch {
            print("❌ [TripsLoadingViewModel] Failed to load trip places: \(error)")
            errorMessage = "Failed to load trip places"
        }

        isLoadingPlaces = false
    }

    // MARK: - Refresh Trip

    /// Refreshes all data for a trip.
    func refreshTrip(tripId: String) async {
        await loadTripDetails(tripId: tripId)
        await loadTripPlaces(tripId: tripId)
    }

    // MARK: - Private Helpers

    /// Fetches place details for a list of place IDs.
    private func fetchPlaceDetails(placeIds: [String]) async throws -> [LightweightPlace] {
        // Use SupabasePlaceService to fetch place details
        var places: [LightweightPlace] = []

        for placeId in placeIds {
            if let place = try? await SupabasePlaceService.shared.fetchLightweightPlace(placeId: placeId) {
                places.append(place)
            }
        }

        return places
    }

    // MARK: - Reset

    /// Resets loading states.
    func resetLoadingStates() {
        isLoadingTrips = false
        isLoadingTripDetails = false
        isLoadingPlaces = false
        errorMessage = nil
    }
}
