//
//  TripDetailViewModel.swift
//  loc
//
//  Parent/coordinator ViewModel for trip detail screen
//  Single Responsibility: Coordinate trip data loading, day place management, and child VMs
//

import Foundation

@MainActor
class TripDetailViewModel: ObservableObject {
    // MARK: - Published State

    @Published var trip: Trip?
    @Published var dayPlaces: [Int: [TripDayPlace]] = [:]
    @Published var isLoading = true
    @Published var isOwner = false
    @Published var canEdit = false
    @Published var error: String?
    @Published var collaborators: [LightweightCollaborator] = []

    // Navigation state
    @Published var selectedDayForDetail: Int?
    @Published var showCollaboratorsSheet = false

    // MARK: - Dependencies

    private let tripService = ServiceContainer.shared.tripService
    private let tripCollaborationService = ServiceContainer.shared.tripCollaborationService

    // MARK: - Properties

    let tripId: String

    // MARK: - Computed

    /// Returns sorted day indices for the trip.
    var dayIndices: [Int] {
        guard let trip = trip else { return [] }
        return Array(0..<trip.numberOfDays)
    }

    /// All place IDs currently in the trip (for "already added" indicators).
    var allPlaceIdsInTrip: Set<String> {
        Set(dayPlaces.values.flatMap { $0 }.map(\.placeId))
    }

    /// Formats a day index into a display label (e.g. "Day 1 · Wed Jan 15").
    func dayLabel(for index: Int) -> String {
        guard let trip = trip else { return "Day \(index + 1)" }
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: index, to: trip.startDate) else {
            return "Day \(index + 1)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return "Day \(index + 1) · \(formatter.string(from: date))"
    }

    // MARK: - Initialization

    init(tripId: String) {
        self.tripId = tripId
    }

    // MARK: - Load Trip

    /// Fetches trip details and organizes places by day index.
    func loadTrip() async {
        isLoading = true
        error = nil

        do {
            let result = try await tripService.fetchTripWithPlaces(tripId: tripId)
            trip = result.trip

            // Organize places by day index
            var grouped: [Int: [TripDayPlace]] = [:]
            for place in result.dayPlaces {
                grouped[place.dayIndex, default: []].append(place)
            }
            // Sort each day's places by sort_order
            for key in grouped.keys {
                grouped[key]?.sort { $0.sortOrder < $1.sortOrder }
            }
            dayPlaces = grouped

            // Fetch collaborators for header display
            await loadCollaborators()

            // Check permissions
            await checkPermissions()
        } catch {
            self.error = error.localizedDescription
            print("[TripDetailVM] Failed to load trip: \(error)")
        }

        isLoading = false
    }

    // MARK: - Collaborators

    /// Fetches collaborators for the trip and updates the published property.
    private func loadCollaborators() async {
        do {
            collaborators = try await tripCollaborationService.fetchCollaborators(tripId: tripId)
        } catch {
            print("[TripDetailVM] Failed to load collaborators: \(error)")
        }
    }

    // MARK: - Permissions

    /// Checks if the current user is the owner or an editor collaborator.
    private func checkPermissions() async {
        guard let trip = trip,
              let userId = await currentUserId() else { return }

        isOwner = trip.ownerId == userId
        if isOwner {
            canEdit = true
        } else {
            canEdit = (try? await tripCollaborationService.canUserEditTrip(
                tripId: tripId, userId: userId
            )) ?? false
        }
    }

    // MARK: - Reorder Places

    /// Moves places within a specific day and persists the new order.
    func reorderPlaces(dayIndex: Int, fromOffsets: IndexSet, toOffset: Int) {
        var places = dayPlaces[dayIndex] ?? []
        places.move(fromOffsets: fromOffsets, toOffset: toOffset)

        // Update sort_order locally
        for (index, var place) in places.enumerated() {
            place.sortOrder = index
            places[index] = place
        }
        dayPlaces[dayIndex] = places

        // Persist reorder via RPC
        let placeIds = places.map(\.id)
        Task {
            try? await tripService.reorderDayPlaces(
                tripId: tripId,
                dayIndex: dayIndex,
                placeIds: placeIds
            )
        }
    }

    // MARK: - Cross-Day Move

    /// Moves a place entry from its current day to a different day.
    func movePlaceToDifferentDay(entryId: String, toDayIndex: Int) async {
        guard let (sourceDayIndex, place) = findPlaceEntry(entryId: entryId),
              sourceDayIndex != toDayIndex else { return }

        // Optimistic local update: remove from source, append to target
        var movedPlace = place
        movedPlace.dayIndex = toDayIndex
        movedPlace.sortOrder = (dayPlaces[toDayIndex]?.last?.sortOrder ?? -1) + 1

        dayPlaces[sourceDayIndex]?.removeAll { $0.id == entryId }
        dayPlaces[toDayIndex, default: []].append(movedPlace)

        // Persist to backend
        do {
            try await tripService.movePlaceToDifferentDay(
                entryId: entryId,
                newDayIndex: toDayIndex,
                tripId: tripId
            )
        } catch {
            print("[TripDetailVM] Failed to move place: \(error)")
            await loadTrip()
        }
    }

    /// Finds a place entry across all days by its entry ID.
    private func findPlaceEntry(entryId: String) -> (dayIndex: Int, place: TripDayPlace)? {
        for (dayIndex, places) in dayPlaces {
            if let place = places.first(where: { $0.id == entryId }) {
                return (dayIndex, place)
            }
        }
        return nil
    }

    // MARK: - Remove Place

    /// Removes a place entry from any day's itinerary by its entry ID.
    func removePlaceFromDay(entryId: String) async {
        guard let (dayIndex, _) = findPlaceEntry(entryId: entryId) else { return }

        do {
            try await tripService.removePlaceFromDay(entryId: entryId)
            dayPlaces[dayIndex]?.removeAll { $0.id == entryId }
        } catch {
            self.error = error.localizedDescription
            print("[TripDetailVM] Failed to remove place: \(error)")
        }
    }

    // MARK: - Add Place

    /// Adds a place to a specific day and refreshes trip data.
    func addPlaceToSpecificDay(placeId: String, dayIndex: Int) async {
        guard let userId = await currentUserId() else { return }

        do {
            try await tripService.addPlaceToDay(
                tripId: tripId,
                placeId: placeId,
                dayIndex: dayIndex,
                addedBy: userId
            )
            // Refresh to get joined data
            await loadTrip()
        } catch {
            self.error = error.localizedDescription
            print("[TripDetailVM] Failed to add place: \(error)")
        }
    }

    // MARK: - Delete Trip

    /// Deletes the entire trip.
    func deleteTrip() async throws {
        try await tripService.deleteTrip(tripId: tripId)
    }

    // MARK: - Helpers

    /// Returns the current user's ID from UserSession.
    private func currentUserId() async -> String? {
        return ServiceContainer.shared.authService.currentUserId
    }
}
