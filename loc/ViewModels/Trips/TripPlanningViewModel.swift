//
//  TripPlanningViewModel.swift
//  loc
//
//  ViewModel for the trip planning view, handling all business logic.
//

import SwiftUI

/// Manages state and business logic for trip planning.
@MainActor
class TripPlanningViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var trip: Trip?
    @Published var dayPlaces: [TripDayPlaces] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var showSearchOverlay: Bool = false
    @Published var selectedDayDate: Date?

    // MARK: - Dependencies

    private let tripService = TripService.shared
    private let placeService = SupabasePlaceService.shared
    let tripId: String

    // MARK: - Initialization

    /// Initializes the view model with a trip ID.
    init(tripId: String) {
        self.tripId = tripId
    }

    // MARK: - Computed Properties

    /// Returns all dates in the trip range.
    var allTripDates: [Date] {
        trip?.allDates ?? []
    }

    /// Returns the total place count across all days.
    var totalPlaceCount: Int {
        dayPlaces.reduce(0) { $0 + $1.places.count }
    }

    // MARK: - Public Methods

    /// Loads the trip and its places from the service.
    func loadTrip() async {
        isLoading = true
        errorMessage = nil

        do {
            trip = try await tripService.fetchTrip(tripId: tripId)
            await loadDayPlaces()
        } catch {
            print("❌ [TripPlanningViewModel] Failed to load trip: \(error)")
            errorMessage = "Failed to load trip"
        }

        isLoading = false
    }

    /// Returns the day number for a given date within the trip.
    func dayNumber(for date: Date) -> Int {
        guard let startDate = trip?.startDate else { return 1 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: date)
        return (components.day ?? 0) + 1
    }

    /// Returns places assigned to a specific day.
    func places(for date: Date) -> [TripPlaceItem] {
        dayPlaces.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })?.places ?? []
    }

    /// Formats the trip date range for display.
    func formattedDateRange() -> String {
        guard let trip = trip else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
    }

    /// Opens the search overlay for a specific day.
    func openSearchForDay(_ date: Date) {
        selectedDayDate = date
        showSearchOverlay = true
    }

    /// Closes the search overlay.
    func closeSearch() {
        showSearchOverlay = false
        selectedDayDate = nil
    }

    /// Adds a place to the currently selected day.
    func addPlace(_ place: LightweightPlace) async {
        guard let dayDate = selectedDayDate else { return }

        let sortOrder = places(for: dayDate).count

        do {
            let tripPlace = try await tripService.addPlaceToTrip(
                tripId: tripId,
                placeId: place.place_id,
                dayDate: dayDate,
                sortOrder: sortOrder
            )

            let item = TripPlaceItem(tripPlace: tripPlace, place: place)
            addPlaceToLocalState(date: dayDate, item: item)
            closeSearch()
        } catch {
            print("❌ [TripPlanningViewModel] Failed to add place: \(error)")
            errorMessage = "Failed to add place"
        }
    }

    /// Removes a place from a specific day.
    func removePlace(placeId: String, from date: Date) async {
        removePlaceFromLocalState(date: date, placeId: placeId)

        do {
            try await tripService.removePlaceFromTrip(tripId: tripId, placeId: placeId, dayDate: date)
        } catch {
            print("❌ [TripPlanningViewModel] Failed to remove place: \(error)")
            errorMessage = "Failed to remove place"
            await loadDayPlaces()
        }
    }

    /// Reorders places within a specific day.
    func reorderPlaces(in date: Date, from: Int, to: Int) async {
        reorderPlacesInLocalState(date: date, fromIndex: from, toIndex: to)

        let placeIds = places(for: date).map { $0.placeId }

        do {
            try await tripService.reorderPlacesInDay(tripId: tripId, dayDate: date, placeIds: placeIds)
        } catch {
            print("❌ [TripPlanningViewModel] Failed to reorder places: \(error)")
            errorMessage = "Failed to reorder places"
            await loadDayPlaces()
        }
    }

    // MARK: - Private Methods

    /// Loads places for the trip grouped by day.
    private func loadDayPlaces() async {
        do {
            var loadedDayPlaces = try await tripService.fetchTripPlacesByDay(tripId: tripId)
            let placeDetails = await fetchPlaceDetails(for: loadedDayPlaces)
            loadedDayPlaces = attachPlaceDetails(to: loadedDayPlaces, details: placeDetails)
            dayPlaces = loadedDayPlaces
        } catch {
            print("❌ [TripPlanningViewModel] Failed to load day places: \(error)")
        }
    }

    /// Fetches place details for all places in the day places array.
    private func fetchPlaceDetails(for dayPlaces: [TripDayPlaces]) async -> [String: LightweightPlace] {
        let allPlaceIds = dayPlaces.flatMap { $0.places.map { $0.placeId } }
        let uniquePlaceIds = Array(Set(allPlaceIds))

        var placeDetailsMap: [String: LightweightPlace] = [:]
        for placeId in uniquePlaceIds {
            if let place = try? await placeService.fetchLightweightPlace(placeId: placeId) {
                placeDetailsMap[placeId] = place
            }
        }
        return placeDetailsMap
    }

    /// Attaches place details to the day places items.
    private func attachPlaceDetails(to dayPlaces: [TripDayPlaces], details: [String: LightweightPlace]) -> [TripDayPlaces] {
        var updatedDayPlaces = dayPlaces
        for dayIndex in updatedDayPlaces.indices {
            for placeIndex in updatedDayPlaces[dayIndex].places.indices {
                let placeId = updatedDayPlaces[dayIndex].places[placeIndex].placeId
                if let place = details[placeId] {
                    let tripPlace = updatedDayPlaces[dayIndex].places[placeIndex].tripPlace
                    updatedDayPlaces[dayIndex].places[placeIndex] = TripPlaceItem(tripPlace: tripPlace, place: place)
                }
            }
        }
        return updatedDayPlaces
    }

    /// Adds a place to local state for a specific day.
    private func addPlaceToLocalState(date: Date, item: TripPlaceItem) {
        if let index = dayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            dayPlaces[index].places.append(item)
        } else {
            dayPlaces.append(TripDayPlaces(date: date, places: [item]))
            dayPlaces.sort { $0.date < $1.date }
        }
    }

    /// Removes a place from local state for a specific day.
    private func removePlaceFromLocalState(date: Date, placeId: String) {
        guard let dayIndex = dayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return
        }
        dayPlaces[dayIndex].places.removeAll { $0.placeId == placeId }
        if dayPlaces[dayIndex].places.isEmpty {
            dayPlaces.remove(at: dayIndex)
        }
    }

    /// Reorders places within a day in local state.
    private func reorderPlacesInLocalState(date: Date, fromIndex: Int, toIndex: Int) {
        guard let dayIndex = dayPlaces.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return
        }
        let item = dayPlaces[dayIndex].places.remove(at: fromIndex)
        dayPlaces[dayIndex].places.insert(item, at: toIndex)
    }
}
