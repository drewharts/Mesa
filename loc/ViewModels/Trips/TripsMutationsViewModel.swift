//
//  TripsMutationsViewModel.swift
//  loc
//
//  Child ViewModel for trip create/update/delete operations.
//

import SwiftUI

/// Manages trip mutation operations (create, update, delete).
@MainActor
class TripsMutationsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Operation in progress flag.
    @Published var isProcessing: Bool = false

    /// Error message for display.
    @Published var errorMessage: String?

    /// Success message for display.
    @Published var successMessage: String?

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

    // MARK: - Create Trip

    /// Creates a new trip with the given parameters.
    func createTrip(name: String, startDate: Date, endDate: Date) async -> Trip? {
        guard let userId = userSession?.currentUserId else {
            errorMessage = "No user session"
            return nil
        }

        guard !name.isEmpty else {
            errorMessage = "Trip name is required"
            return nil
        }

        guard startDate <= endDate else {
            errorMessage = "End date must be after start date"
            return nil
        }

        guard !isProcessing else { return nil }
        isProcessing = true
        errorMessage = nil

        do {
            let trip = try await tripService.createTrip(
                userId: userId,
                name: name,
                startDate: startDate,
                endDate: endDate
            )

            // Add to local state
            let lightweightTrip = LightweightTrip(from: trip, placeCount: 0)
            dataViewModel?.addTrip(lightweightTrip)
            dataViewModel?.setRecentlyCreatedTrip(trip.id)

            successMessage = "Trip created!"
            isProcessing = false
            return trip
        } catch {
            print("❌ [TripsMutationsViewModel] Failed to create trip: \(error)")
            errorMessage = "Failed to create trip"
            isProcessing = false
            return nil
        }
    }

    // MARK: - Update Trip

    /// Updates an existing trip's metadata.
    func updateTrip(tripId: String, name: String?, startDate: Date?, endDate: Date?) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil

        do {
            try await tripService.updateTrip(
                tripId: tripId,
                name: name,
                startDate: startDate,
                endDate: endDate
            )

            // Update local state
            if let existingTrip = dataViewModel?.trips.first(where: { $0.tripId == tripId }) {
                let updated = LightweightTrip(
                    tripId: existingTrip.tripId,
                    name: name ?? existingTrip.name,
                    startDate: startDate ?? existingTrip.startDate,
                    endDate: endDate ?? existingTrip.endDate,
                    coverImage: existingTrip.coverImage,
                    placeCount: existingTrip.placeCount,
                    createdAt: existingTrip.createdAt
                )
                dataViewModel?.updateTrip(updated)
            }

            successMessage = "Trip updated!"
            isProcessing = false
            return true
        } catch {
            print("❌ [TripsMutationsViewModel] Failed to update trip: \(error)")
            errorMessage = "Failed to update trip"
            isProcessing = false
            return false
        }
    }

    // MARK: - Delete Trip

    /// Deletes a trip and all its places.
    func deleteTrip(tripId: String) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil

        // Optimistic update - remove from local state first
        dataViewModel?.removeTrip(tripId: tripId)

        do {
            try await tripService.deleteTrip(tripId: tripId)
            successMessage = "Trip deleted"
            isProcessing = false
            return true
        } catch {
            print("❌ [TripsMutationsViewModel] Failed to delete trip: \(error)")
            errorMessage = "Failed to delete trip"

            // Revert optimistic update if needed (would require caching removed trip)
            isProcessing = false
            return false
        }
    }

    // MARK: - Add Place to Trip

    /// Adds a place to a specific day in a trip.
    func addPlaceToTrip(tripId: String, placeId: String, dayDate: Date, place: LightweightPlace?) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil

        do {
            let sortOrder = calculateNextSortOrder(for: dayDate)

            let tripPlace = try await tripService.addPlaceToTrip(
                tripId: tripId,
                placeId: placeId,
                dayDate: dayDate,
                sortOrder: sortOrder
            )

            // Update local state
            let item = TripPlaceItem(tripPlace: tripPlace, place: place)
            dataViewModel?.addPlaceToDay(date: dayDate, item: item)

            if let place = place {
                dataViewModel?.cachePlaces([place])
            }

            isProcessing = false
            return true
        } catch {
            print("❌ [TripsMutationsViewModel] Failed to add place to trip: \(error)")
            errorMessage = "Failed to add place"
            isProcessing = false
            return false
        }
    }

    // MARK: - Remove Place from Trip

    /// Removes a place from a specific day in a trip.
    func removePlaceFromTrip(tripId: String, placeId: String, dayDate: Date) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil

        // Optimistic update
        dataViewModel?.removePlaceFromDay(date: dayDate, placeId: placeId)

        do {
            try await tripService.removePlaceFromTrip(tripId: tripId, placeId: placeId, dayDate: dayDate)
            isProcessing = false
            return true
        } catch {
            print("❌ [TripsMutationsViewModel] Failed to remove place from trip: \(error)")
            errorMessage = "Failed to remove place"
            isProcessing = false
            return false
        }
    }

    // MARK: - Move Place Between Days

    /// Moves a place from one day to another within a trip.
    func movePlaceToDay(tripId: String, placeId: String, fromDate: Date, toDate: Date) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil

        let newSortOrder = calculateNextSortOrder(for: toDate)

        // Optimistic update
        dataViewModel?.movePlaceBetweenDays(placeId: placeId, fromDate: fromDate, toDate: toDate)

        do {
            try await tripService.movePlaceToDay(
                tripId: tripId,
                placeId: placeId,
                fromDate: fromDate,
                toDate: toDate,
                newSortOrder: newSortOrder
            )
            isProcessing = false
            return true
        } catch {
            print("❌ [TripsMutationsViewModel] Failed to move place: \(error)")
            errorMessage = "Failed to move place"
            isProcessing = false
            return false
        }
    }

    // MARK: - Reorder Places

    /// Reorders places within a day.
    func reorderPlacesInDay(tripId: String, dayDate: Date, fromIndex: Int, toIndex: Int) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil

        // Optimistic update
        dataViewModel?.reorderPlacesInDay(date: dayDate, fromIndex: fromIndex, toIndex: toIndex)

        // Get updated order
        guard let dayPlaces = dataViewModel?.tripDayPlaces.first(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }) else {
            isProcessing = false
            return false
        }

        let placeIds = dayPlaces.places.map { $0.placeId }

        do {
            try await tripService.reorderPlacesInDay(tripId: tripId, dayDate: dayDate, placeIds: placeIds)
            isProcessing = false
            return true
        } catch {
            print("❌ [TripsMutationsViewModel] Failed to reorder places: \(error)")
            errorMessage = "Failed to reorder places"
            isProcessing = false
            return false
        }
    }

    // MARK: - Private Helpers

    /// Calculates the next sort order for a new place on a day.
    private func calculateNextSortOrder(for date: Date) -> Int {
        guard let dayPlaces = dataViewModel?.tripDayPlaces.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return 0
        }
        return dayPlaces.places.count
    }

    // MARK: - Reset

    /// Clears error and success messages.
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    /// Resets all mutation state.
    func resetAllData() {
        isProcessing = false
        errorMessage = nil
        successMessage = nil
    }
}
