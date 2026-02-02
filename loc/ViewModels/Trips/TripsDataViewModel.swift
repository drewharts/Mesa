//
//  TripsDataViewModel.swift
//  loc
//
//  Child ViewModel for core trip data storage.
//

import SwiftUI

/// Manages core trip data storage and state.
@MainActor
class TripsDataViewModel: ObservableObject {
    // MARK: - Published Properties

    /// User's trips (lightweight format for list display).
    @Published var trips: [LightweightTrip] = []

    /// Currently selected/editing trip (full format).
    @Published var currentTrip: Trip?

    /// Places grouped by day for the current trip.
    @Published var tripDayPlaces: [TripDayPlaces] = []

    /// Place details cache by place ID.
    @Published var placesCache: [String: LightweightPlace] = [:]

    /// Recently created trip ID (for highlighting).
    @Published var recentlyCreatedTripId: UUID?

    // MARK: - Private State

    private var tripCreationTime: Date?

    // MARK: - Dependencies

    private weak var userSession: UserSession?

    // MARK: - Initialization

    /// Initializes the data view model with required dependencies.
    init(userSession: UserSession) {
        self.userSession = userSession
    }

    // MARK: - Trip State Management

    /// Sets the trips list with deduplication.
    func setTrips(_ newTrips: [LightweightTrip]) {
        var seenIds = Set<String>()
        let uniqueTrips = newTrips.filter { trip in
            if seenIds.contains(trip.tripId) {
                return false
            }
            seenIds.insert(trip.tripId)
            return true
        }
        trips = uniqueTrips
    }

    /// Adds a new trip to the list at the top.
    func addTrip(_ trip: LightweightTrip) {
        trips.insert(trip, at: 0)
    }

    /// Removes a trip from the list.
    func removeTrip(tripId: String) {
        trips.removeAll { $0.tripId == tripId }
    }

    /// Updates a trip in the list.
    func updateTrip(_ updatedTrip: LightweightTrip) {
        guard let index = trips.firstIndex(where: { $0.tripId == updatedTrip.tripId }) else {
            return
        }
        trips[index] = updatedTrip
    }

    // MARK: - Day Places Management

    /// Sets day places for the current trip.
    func setDayPlaces(_ dayPlaces: [TripDayPlaces]) {
        tripDayPlaces = dayPlaces
    }

    /// Adds a place to a specific day.
    func addPlaceToDay(date: Date, item: TripPlaceItem) {
        if let index = tripDayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            var day = tripDayPlaces[index]
            day.places.append(item)
            day.places.sort { $0.sortOrder < $1.sortOrder }
            tripDayPlaces[index] = day
        } else {
            // Create new day entry
            let newDay = TripDayPlaces(date: date, places: [item])
            tripDayPlaces.append(newDay)
            tripDayPlaces.sort { $0.date < $1.date }
        }

        // Update trip place count
        updateTripPlaceCount()
    }

    /// Removes a place from a specific day.
    func removePlaceFromDay(date: Date, placeId: String) {
        guard let dayIndex = tripDayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return
        }

        tripDayPlaces[dayIndex].places.removeAll { $0.placeId == placeId }

        // Remove empty days
        if tripDayPlaces[dayIndex].places.isEmpty {
            tripDayPlaces.remove(at: dayIndex)
        }

        // Update trip place count
        updateTripPlaceCount()
    }

    /// Moves a place from one day to another.
    func movePlaceBetweenDays(placeId: String, fromDate: Date, toDate: Date) {
        guard let fromDayIndex = tripDayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: fromDate) }),
              let placeIndex = tripDayPlaces[fromDayIndex].places.firstIndex(where: { $0.placeId == placeId }) else {
            return
        }

        var item = tripDayPlaces[fromDayIndex].places[placeIndex]
        tripDayPlaces[fromDayIndex].places.remove(at: placeIndex)

        // Remove empty days
        if tripDayPlaces[fromDayIndex].places.isEmpty {
            tripDayPlaces.remove(at: fromDayIndex)
        }

        // Add to target day
        if let toDayIndex = tripDayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: toDate) }) {
            // Update the item with new date
            let newTripPlace = TripPlace(
                id: item.tripPlace.id,
                tripId: item.tripPlace.tripId,
                placeId: item.tripPlace.placeId,
                dayDate: toDate,
                sortOrder: tripDayPlaces[toDayIndex].places.count,
                notes: item.tripPlace.notes,
                createdAt: item.tripPlace.createdAt
            )
            item = TripPlaceItem(tripPlace: newTripPlace, place: item.place)
            tripDayPlaces[toDayIndex].places.append(item)
        } else {
            // Create new day
            let newTripPlace = TripPlace(
                id: item.tripPlace.id,
                tripId: item.tripPlace.tripId,
                placeId: item.tripPlace.placeId,
                dayDate: toDate,
                sortOrder: 0,
                notes: item.tripPlace.notes,
                createdAt: item.tripPlace.createdAt
            )
            item = TripPlaceItem(tripPlace: newTripPlace, place: item.place)
            let newDay = TripDayPlaces(date: toDate, places: [item])
            tripDayPlaces.append(newDay)
            tripDayPlaces.sort { $0.date < $1.date }
        }
    }

    /// Reorders places within a day.
    func reorderPlacesInDay(date: Date, fromIndex: Int, toIndex: Int) {
        guard let dayIndex = tripDayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return
        }

        let item = tripDayPlaces[dayIndex].places.remove(at: fromIndex)
        tripDayPlaces[dayIndex].places.insert(item, at: toIndex)

        // Update sort orders
        for (index, var place) in tripDayPlaces[dayIndex].places.enumerated() {
            let updatedTripPlace = TripPlace(
                id: place.tripPlace.id,
                tripId: place.tripPlace.tripId,
                placeId: place.tripPlace.placeId,
                dayDate: place.tripPlace.dayDate,
                sortOrder: index,
                notes: place.tripPlace.notes,
                createdAt: place.tripPlace.createdAt
            )
            place = TripPlaceItem(tripPlace: updatedTripPlace, place: place.place)
            tripDayPlaces[dayIndex].places[index] = place
        }
    }

    // MARK: - Place Cache

    /// Caches place details for display.
    func cachePlaces(_ places: [LightweightPlace]) {
        for place in places {
            placesCache[place.place_id] = place
        }
    }

    /// Gets a cached place by ID.
    func getCachedPlace(placeId: String) -> LightweightPlace? {
        placesCache[placeId]
    }

    // MARK: - Recently Created Trip

    /// Sets the recently created trip ID.
    func setRecentlyCreatedTrip(_ tripId: UUID) {
        recentlyCreatedTripId = tripId
        tripCreationTime = Date()
    }

    /// Clears the recently created trip flag.
    func clearRecentlyCreatedTrip() {
        recentlyCreatedTripId = nil
        tripCreationTime = nil
    }

    /// Checks if a trip is recently created (within last 60 seconds).
    func isTripRecentlyCreated(_ tripId: String) -> Bool {
        guard let createdId = recentlyCreatedTripId,
              let creationTime = tripCreationTime,
              createdId.uuidString == tripId else {
            return false
        }
        return Date().timeIntervalSince(creationTime) < 60
    }

    // MARK: - Private Helpers

    /// Updates the place count for the current trip in the trips list.
    private func updateTripPlaceCount() {
        guard let currentTripId = currentTrip?.id.uuidString else { return }

        let totalPlaces = tripDayPlaces.reduce(0) { $0 + $1.places.count }

        if let index = trips.firstIndex(where: { $0.tripId == currentTripId }) {
            let trip = trips[index]
            let updated = LightweightTrip(
                tripId: trip.tripId,
                name: trip.name,
                startDate: trip.startDate,
                endDate: trip.endDate,
                coverImage: trip.coverImage,
                placeCount: totalPlaces,
                createdAt: trip.createdAt
            )
            trips[index] = updated
        }
    }

    // MARK: - Reset

    /// Resets all trip data (used during logout).
    func resetAllData() {
        trips.removeAll()
        currentTrip = nil
        tripDayPlaces.removeAll()
        placesCache.removeAll()
        recentlyCreatedTripId = nil
        tripCreationTime = nil
    }
}
