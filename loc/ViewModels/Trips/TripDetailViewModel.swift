//
//  TripDetailViewModel.swift
//  loc
//
//  Parent/coordinator ViewModel for trip detail screen
//  Single Responsibility: Coordinate trip data loading, day place management, and child VMs
//

import Foundation
import Combine

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
    @Published var selectedPlaceIdForDetail: String?
    @Published var showCollaboratorsSheet = false

    // MARK: - Child ViewModels

    let travelTimesViewModel = TripTravelTimesViewModel()

    // MARK: - Dependencies

    private let tripService = ServiceContainer.shared.tripService
    private let tripCollaborationService = ServiceContainer.shared.tripCollaborationService

    // MARK: - Properties

    let tripId: String
    private var hasPerformedInitialLoad = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Map Coordinator

    /// Reference to the map display coordinator for annotation management.
    private weak var mapCoordinator: MapDisplayCoordinatorViewModel?

    /// Sets the map display coordinator reference for annotation management.
    func setMapCoordinator(_ coordinator: MapDisplayCoordinatorViewModel) {
        self.mapCoordinator = coordinator
    }

    // MARK: - Computed

    /// Summary from the trips list (name/dates) shown while the detail loads.
    var seedSummary: LightweightTrip? { TripDataCache.shared.summary(for: tripId) }

    /// Returns sorted day indices for the trip.
    var dayIndices: [Int] {
        guard let trip = trip else { return [] }
        return Array(0..<trip.numberOfDays)
    }

    /// All place IDs currently in the trip (for "already added" indicators).
    var allPlaceIdsInTrip: Set<String> {
        Set(dayPlaces.values.flatMap { $0 }.map(\.placeId))
    }

    /// Whether any assigned day place has coordinates for map display.
    var hasPlacesWithCoordinates: Bool {
        dayPlaces.contains { dayIndex, places in
            dayIndex >= 0 && places.contains { $0.placeLatitude != nil && $0.placeLongitude != nil }
        }
    }

    /// Builds trip map annotations, optionally filtered to a specific day.
    func buildTripAnnotations(forDay dayFilter: Int? = nil) -> [TripMapAnnotation] {
        TripMapViewModel.buildAnnotations(
            dayPlaces: dayPlaces,
            dayIndices: dayIndices,
            selectedDayFilter: dayFilter
        )
    }

    /// Places saved as unassigned Ideas (dayIndex = -1).
    var ideaPlaces: [TripDayPlace] {
        dayPlaces[TripDayPlace.ideasDayIndex] ?? []
    }

    /// Formats a day index into a display label (e.g. "Day 1 · Wed Jan 15").
    func dayLabel(for index: Int) -> String {
        guard let trip = trip else { return "Day \(index + 1)" }
        guard let date = Trip.utcCalendar.date(byAdding: .day, value: index, to: trip.startDate) else {
            return "Day \(index + 1)"
        }
        let formatter = Trip.utcDateFormatter(format: "EEE MMM d")
        return "Day \(index + 1) · \(formatter.string(from: date))"
    }

    // MARK: - Initialization

    init(tripId: String) {
        self.tripId = tripId
        travelTimesViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Load Trip

    /// Fetches trip details and organizes places by day index.
    /// Shows cached data instantly (if any), then refreshes from the network.
    /// Collaborators and permissions load in parallel after the itinerary is on screen.
    func loadTrip() async {
        if trip == nil, let cached = TripDataCache.shared.detail(for: tripId) {
            trip = cached.trip
            dayPlaces = cached.dayPlaces
            isOwner = cached.trip.ownerId == ServiceContainer.shared.authService.currentUserId
            if isOwner { canEdit = true }
            travelTimesViewModel.recalculate(dayPlaces: dayPlaces)
        }
        isLoading = trip == nil
        error = nil

        do {
            let result = try await tripService.fetchTripWithPlaces(tripId: tripId)

            // Organize places by day index
            var grouped: [Int: [TripDayPlace]] = [:]
            for place in result.dayPlaces {
                grouped[place.dayIndex, default: []].append(place)
            }
            // Sort each day's places by sort_order
            for key in grouped.keys {
                grouped[key]?.sort { $0.sortOrder < $1.sortOrder }
            }
            trip = result.trip
            if grouped != dayPlaces {
                dayPlaces = grouped
            }
            TripDataCache.shared.storeDetail(trip: result.trip, dayPlaces: grouped)
            isLoading = false
            travelTimesViewModel.recalculate(dayPlaces: dayPlaces)

            // Prefetch external content metadata for PopupPlaceCard thumbnail display
            let contentUrls = result.dayPlaces.compactMap(\.contentUrl).filter { !$0.isEmpty }
            if !contentUrls.isEmpty {
                Task {
                    await ExternalMetadataCache.shared.prefetchMetadata(for: contentUrls)
                }
            }

            // Warm place details so tapping a stop opens instantly
            prefetchPlaceDetails(placeIds: result.dayPlaces.map(\.placeId))

            // Collaborators + permissions in parallel (no longer block the itinerary)
            async let collaboratorsLoad: Void = loadCollaborators()
            async let permissionsLoad: Void = checkPermissions()
            _ = await (collaboratorsLoad, permissionsLoad)
        } catch {
            if trip == nil {
                self.error = error.localizedDescription
            }
            print("[TripDetailVM] Failed to load trip: \(error)")
        }

        isLoading = false
    }

    /// Fetches place details for the trip's stops in the background (cached in TripDataCache).
    private func prefetchPlaceDetails(placeIds: [String]) {
        let missing = Array(Set(placeIds).filter { TripDataCache.shared.place(for: $0) == nil }).prefix(40)
        guard !missing.isEmpty else { return }
        Task(priority: .utility) {
            await withTaskGroup(of: (String, DetailPlace?).self) { group in
                for placeId in missing {
                    group.addTask {
                        let place = try? await PlaceService.shared.fetchPlace(withId: placeId)
                        return (placeId, place)
                    }
                }
                for await (placeId, place) in group {
                    if let place {
                        TripDataCache.shared.storePlace(place, id: placeId)
                    }
                }
            }
        }
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
        applyDayOrder(dayIndex: dayIndex, places: places)
    }

    /// Sets a day's order locally (sort_order = position), refreshes map/routes, persists via RPC,
    /// and rolls back to the previous order if the save fails.
    func applyDayOrder(dayIndex: Int, places newOrder: [TripDayPlace]) {
        let previous = dayPlaces[dayIndex] ?? []
        var places = newOrder
        for index in places.indices {
            places[index].sortOrder = index
        }
        guard places.map(\.id) != previous.map(\.id) || places.map(\.sortOrder) != previous.map(\.sortOrder) else {
            return
        }
        dayPlaces[dayIndex] = places
        travelTimesViewModel.recalculateDay(dayIndex: dayIndex, places: places)
        refreshMapAnnotations()

        let entryIds = places.map(\.id)
        Task {
            do {
                try await tripService.reorderDayPlaces(
                    tripId: tripId,
                    dayIndex: dayIndex,
                    placeIds: entryIds
                )
            } catch {
                print("[TripDetailVM] Failed to reorder: \(error)")
                dayPlaces[dayIndex] = previous
                travelTimesViewModel.recalculateDay(dayIndex: dayIndex, places: previous)
                refreshMapAnnotations()
            }
        }
    }

    /// Moves a stop up (-1) or down (+1) within its day.
    func moveStop(entryId: String, by offset: Int) {
        guard let (dayIndex, index) = indexOfEntry(entryId) else { return }
        var places = dayPlaces[dayIndex] ?? []
        let target = index + offset
        guard places.indices.contains(target) else { return }
        places.swapAt(index, target)
        applyDayOrder(dayIndex: dayIndex, places: places)
    }

    /// Drag-and-drop: moves a stop so it sits just before `beforeEntryId`
    /// (or at the end of `dayIndex` when nil). Handles same-day and cross-day moves.
    func moveStop(entryId: String, toDayIndex: Int, beforeEntryId: String?) async {
        guard canEdit, entryId != beforeEntryId,
              let (sourceDay, sourceIndex) = indexOfEntry(entryId) else { return }
        let moving = dayPlaces[sourceDay]![sourceIndex]

        if sourceDay == toDayIndex {
            var places = dayPlaces[toDayIndex] ?? []
            places.remove(at: sourceIndex)
            let insertAt = beforeEntryId.flatMap { id in places.firstIndex(where: { $0.id == id }) } ?? places.count
            places.insert(moving, at: insertAt)
            applyDayOrder(dayIndex: toDayIndex, places: places)
            return
        }

        // Cross-day: existing move (appends to target day), then position it.
        await movePlaceToDifferentDay(entryId: entryId, toDayIndex: toDayIndex)
        guard var places = dayPlaces[toDayIndex],
              let movedIndex = places.firstIndex(where: { $0.id == entryId }) else { return }
        let moved = places.remove(at: movedIndex)
        let insertAt = beforeEntryId.flatMap { id in places.firstIndex(where: { $0.id == id }) } ?? places.count
        places.insert(moved, at: insertAt)
        applyDayOrder(dayIndex: toDayIndex, places: places)
        refreshMapAnnotations()
    }

    // MARK: - Insert Between Stops

    /// Where a new stop should be inserted (presented as the existing Add Place sheet).
    struct InsertRequest: Identifiable, Equatable {
        let id = UUID()
        let dayIndex: Int
        /// Insert after this entry; nil = at the start of the day.
        let afterEntryId: String?
        let existingEntryIds: Set<String>
    }

    /// Drives the Add Place sheet for an insert.
    @Published var insertRequest: InsertRequest?
    /// Kept after the sheet closes so onDismiss can finish positioning.
    private var pendingInsert: InsertRequest?

    /// Opens the existing Add Place sheet targeting `dayIndex`, to insert after `afterEntryId`.
    func requestInsert(dayIndex: Int, afterEntryId: String?, presentFromOverview: Bool = true) {
        guard canEdit else { return }
        let existing = Set((dayPlaces[dayIndex] ?? []).map(\.id))
        let request = InsertRequest(dayIndex: dayIndex, afterEntryId: afterEntryId, existingEntryIds: existing)
        pendingInsert = request
        if presentFromOverview {
            insertRequest = request
        }
    }

    /// After the Add Place sheet closes: reloads, then moves newly added stops into position.
    func completePendingInsert() async {
        guard let request = pendingInsert else { return }
        pendingInsert = nil
        await loadTrip()

        let places = dayPlaces[request.dayIndex] ?? []
        let added = places.filter { !request.existingEntryIds.contains($0.id) }
        guard !added.isEmpty else {
            refreshMapAnnotations()
            return
        }
        var remaining = places.filter { request.existingEntryIds.contains($0.id) }
        let insertAt: Int
        if let afterId = request.afterEntryId, let afterIndex = remaining.firstIndex(where: { $0.id == afterId }) {
            insertAt = afterIndex + 1
        } else if request.afterEntryId == nil {
            insertAt = 0
        } else {
            insertAt = remaining.count
        }
        remaining.insert(contentsOf: added, at: insertAt)
        applyDayOrder(dayIndex: request.dayIndex, places: remaining)
        refreshMapAnnotations()
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
        travelTimesViewModel.recalculateDay(dayIndex: sourceDayIndex, places: dayPlaces[sourceDayIndex] ?? [])
        travelTimesViewModel.recalculateDay(dayIndex: toDayIndex, places: dayPlaces[toDayIndex] ?? [])

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

    /// Moves a place from a calendar day back to Ideas (dayIndex = -1).
    func removePlaceFromDay(entryId: String) async {
        await movePlaceToDifferentDay(entryId: entryId, toDayIndex: TripDayPlace.ideasDayIndex)
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

    // MARK: - Visited

    /// First not-yet-visited stop in a day (in itinerary order).
    func nextStopId(dayIndex: Int) -> String? {
        guard dayIndex >= 0 else { return nil }
        let places = dayPlaces[dayIndex] ?? []
        return places.first(where: { !$0.isVisited })?.id
    }

    /// Toggles a stop's visited state optimistically and persists it; rolls back on failure.
    func toggleVisited(entryId: String) {
        guard canEdit,
              let (dayIndex, index) = indexOfEntry(entryId) else { return }
        var place = dayPlaces[dayIndex]![index]

        let previousAt = place.visitedAt
        let previousBy = place.visitedBy
        let userId = ServiceContainer.shared.authService.currentUserId

        if place.isVisited {
            place.visitedAt = nil
            place.visitedBy = nil
        } else {
            place.visitedAt = ISO8601DateFormatter().string(from: Date())
            place.visitedBy = userId
        }
        dayPlaces[dayIndex]?[index] = place
        refreshMapAnnotations()

        let newAt = place.visitedAt
        let newBy = place.visitedBy
        Task {
            do {
                try await tripService.setVisited(entryId: entryId, visitedAt: newAt, visitedBy: newBy)
            } catch {
                print("[TripDetailVM] Failed to update visited: \(error)")
                if let (d, i) = indexOfEntry(entryId) {
                    dayPlaces[d]?[i].visitedAt = previousAt
                    dayPlaces[d]?[i].visitedBy = previousBy
                    refreshMapAnnotations()
                }
            }
        }
    }

    /// Day index and array index for an entry id.
    private func indexOfEntry(_ entryId: String) -> (Int, Int)? {
        for (dayIndex, places) in dayPlaces {
            if let index = places.firstIndex(where: { $0.id == entryId }) {
                return (dayIndex, index)
            }
        }
        return nil
    }

    /// Re-sends annotations to the main map (respecting the current day filter).
    private func refreshMapAnnotations() {
        guard let coordinator = mapCoordinator,
              coordinator.activeTripId == nil || coordinator.activeTripId == tripId else { return }
        let annotations = buildTripAnnotations(forDay: selectedDayForDetail)
        mapCoordinator?.showTripOnMap(annotations: annotations, tripId: tripId)
    }

    // MARK: - Ideas

    /// Deletes an Idea entry permanently by its entry ID.
    func removeIdea(entryId: String) async {
        guard let (dayIndex, _) = findPlaceEntry(entryId: entryId) else { return }

        do {
            try await tripService.removePlaceFromDay(entryId: entryId)
            dayPlaces[dayIndex]?.removeAll { $0.id == entryId }
        } catch {
            self.error = error.localizedDescription
            print("[TripDetailVM] Failed to remove idea: \(error)")
        }
    }

    /// Moves an Idea to a specific calendar day.
    func moveIdeaToDay(entryId: String, dayIndex: Int) async {
        await movePlaceToDifferentDay(entryId: entryId, toDayIndex: dayIndex)
    }

    // MARK: - Drop Handling

    /// Routes a calendar day drop to either a move (from Ideas) or a new place add.
    func handleCalendarDrop(droppedId: String, dayIndex: Int) {
        let ideaEntryIds = Set(ideaPlaces.map(\.id))
        if ideaEntryIds.contains(droppedId) {
            Task { await moveIdeaToDay(entryId: droppedId, dayIndex: dayIndex) }
        } else if indexOfEntry(droppedId) != nil {
            // A scheduled stop dragged from the itinerary onto a calendar day
            Task { await moveStop(entryId: droppedId, toDayIndex: dayIndex, beforeEntryId: nil) }
        } else {
            Task { await addPlaceToSpecificDay(placeId: droppedId, dayIndex: dayIndex) }
        }
    }

    // MARK: - Delete Trip

    /// Deletes the entire trip.
    func deleteTrip() async throws {
        try await tripService.deleteTrip(tripId: tripId)
        TripDataCache.shared.removeTrip(tripId)
    }

    // MARK: - Map Annotation Coordination

    /// Loads trip data and shows annotations on the map (runs only once per view lifecycle).
    func loadTripAndShowAnnotations() async {
        guard !hasPerformedInitialLoad else { return }
        hasPerformedInitialLoad = true
        await loadTrip()
        if hasPlacesWithCoordinates {
            let annotations = buildTripAnnotations()
            mapCoordinator?.showTripOnMap(annotations: annotations, tripId: tripId)
        }
    }

    /// Handles day filter changes: filters annotations or restores all after reload.
    func handleDayFilterChange(old: Int?, new: Int?) async {
        if old != nil && new == nil {
            // Restore the full-trip map from local state right away, then refresh quietly
            mapCoordinator?.showTripOnMap(annotations: buildTripAnnotations(), tripId: tripId)
            let before = dayPlaces
            await loadTrip()
            if dayPlaces != before {
                mapCoordinator?.showTripOnMap(annotations: buildTripAnnotations(), tripId: tripId)
            }
        } else if let dayIndex = new {
            let annotations = buildTripAnnotations(forDay: dayIndex)
            mapCoordinator?.showTripOnMap(annotations: annotations, tripId: tripId)
        }
    }

    /// Clears trip annotations from the map.
    func clearMapAnnotations() {
        mapCoordinator?.clearTripAnnotations()
    }

    /// Highlights a trip annotation on the map by setting the selected place ID.
    func highlightTripAnnotation(placeId: String?) {
        mapCoordinator?.selectedTripAnnotationPlaceId = placeId
    }

    /// Handles a trip place tap from the map by setting navigation state.
    func handleMapPlaceTap(_ placeId: String?) {
        guard let placeId else { return }
        mapCoordinator?.tappedTripPlaceId = nil
        selectedPlaceIdForDetail = placeId
    }

    // MARK: - Helpers

    /// Returns the current user's ID from UserSession.
    private func currentUserId() async -> String? {
        return ServiceContainer.shared.authService.currentUserId
    }
}
