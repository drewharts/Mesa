//
//  ProfileTripsViewModel.swift
//  loc
//
//  Coordinator ViewModel for trip management in the profile.
//  Composes child ViewModels for specific responsibilities.
//

import SwiftUI
import Combine

/// Coordinates trip management for the current user's profile.
@MainActor
class ProfileTripsViewModel: ObservableObject {
    // MARK: - Child ViewModels

    /// Core trip data storage.
    let dataViewModel: TripsDataViewModel

    /// Trip loading operations.
    let loadingViewModel: TripsLoadingViewModel

    /// Trip create/update/delete operations.
    let mutationsViewModel: TripsMutationsViewModel

    /// Calendar date selection state.
    let dateSelectionViewModel: TripDateSelectionViewModel

    /// Drag-and-drop state management.
    let dragDropViewModel: TripDragDropViewModel

    // MARK: - Combine Subscriptions

    /// Stores subscriptions to child ViewModels for change propagation.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private weak var userSession: UserSession?
    private weak var locationManager: LocationManager?

    // MARK: - Proxy Properties for Backward Compatibility

    /// User's trips.
    var trips: [LightweightTrip] {
        get { dataViewModel.trips }
        set { dataViewModel.setTrips(newValue) }
    }

    /// Current trip being edited.
    var currentTrip: Trip? {
        get { dataViewModel.currentTrip }
        set { dataViewModel.currentTrip = newValue }
    }

    /// Trip day places for current trip.
    var tripDayPlaces: [TripDayPlaces] {
        get { dataViewModel.tripDayPlaces }
        set { dataViewModel.setDayPlaces(newValue) }
    }

    /// Loading trips state.
    var isLoadingTrips: Bool {
        loadingViewModel.isLoadingTrips
    }

    /// Loading trip details state.
    var isLoadingTripDetails: Bool {
        loadingViewModel.isLoadingTripDetails
    }

    /// Processing mutation state.
    var isProcessing: Bool {
        mutationsViewModel.isProcessing
    }

    /// Error message.
    var errorMessage: String? {
        loadingViewModel.errorMessage ?? mutationsViewModel.errorMessage
    }

    /// Success message.
    var successMessage: String? {
        mutationsViewModel.successMessage
    }

    /// Recently created trip ID.
    var recentlyCreatedTripId: UUID? {
        dataViewModel.recentlyCreatedTripId
    }

    // MARK: - Initialization

    /// Initializes the trips view model with required dependencies.
    init(userSession: UserSession, locationManager: LocationManager) {
        self.userSession = userSession
        self.locationManager = locationManager

        // Create child ViewModels
        let dataVM = TripsDataViewModel(userSession: userSession)
        let loadingVM = TripsLoadingViewModel(userSession: userSession, dataViewModel: dataVM)
        let mutationsVM = TripsMutationsViewModel(userSession: userSession, dataViewModel: dataVM)
        let dateSelectionVM = TripDateSelectionViewModel()
        let dragDropVM = TripDragDropViewModel()

        // Store references
        self.dataViewModel = dataVM
        self.loadingViewModel = loadingVM
        self.mutationsViewModel = mutationsVM
        self.dateSelectionViewModel = dateSelectionVM
        self.dragDropViewModel = dragDropVM

        // Wire up child ViewModel change propagation
        setupChildViewModelObservers()
    }

    // MARK: - Child ViewModel Change Propagation

    /// Subscribes to child ViewModels and forwards their changes to trigger parent updates.
    private func setupChildViewModelObservers() {
        dataViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        loadingViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        mutationsViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        dateSelectionViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        dragDropViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Delegated Methods - Loading

    /// Loads all trips for the current user.
    func loadUserTrips() async {
        await loadingViewModel.loadUserTrips()
    }

    /// Loads a specific trip's details.
    func loadTripDetails(tripId: String) async {
        await loadingViewModel.loadTripDetails(tripId: tripId)
    }

    /// Loads places for a trip.
    func loadTripPlaces(tripId: String) async {
        await loadingViewModel.loadTripPlaces(tripId: tripId)
    }

    /// Refreshes all data for a trip.
    func refreshTrip(tripId: String) async {
        await loadingViewModel.refreshTrip(tripId: tripId)
    }

    // MARK: - Delegated Methods - Mutations

    /// Creates a new trip.
    func createTrip(name: String, startDate: Date, endDate: Date) async -> Trip? {
        await mutationsViewModel.createTrip(name: name, startDate: startDate, endDate: endDate)
    }

    /// Updates an existing trip.
    func updateTrip(tripId: String, name: String?, startDate: Date?, endDate: Date?) async -> Bool {
        await mutationsViewModel.updateTrip(tripId: tripId, name: name, startDate: startDate, endDate: endDate)
    }

    /// Deletes a trip.
    func deleteTrip(tripId: String) async -> Bool {
        await mutationsViewModel.deleteTrip(tripId: tripId)
    }

    /// Adds a place to a trip.
    func addPlaceToTrip(tripId: String, placeId: String, dayDate: Date, place: LightweightPlace?) async -> Bool {
        await mutationsViewModel.addPlaceToTrip(tripId: tripId, placeId: placeId, dayDate: dayDate, place: place)
    }

    /// Removes a place from a trip.
    func removePlaceFromTrip(tripId: String, placeId: String, dayDate: Date) async -> Bool {
        await mutationsViewModel.removePlaceFromTrip(tripId: tripId, placeId: placeId, dayDate: dayDate)
    }

    /// Moves a place between days.
    func movePlaceToDay(tripId: String, placeId: String, fromDate: Date, toDate: Date) async -> Bool {
        await mutationsViewModel.movePlaceToDay(tripId: tripId, placeId: placeId, fromDate: fromDate, toDate: toDate)
    }

    /// Reorders places within a day.
    func reorderPlacesInDay(tripId: String, dayDate: Date, fromIndex: Int, toIndex: Int) async -> Bool {
        await mutationsViewModel.reorderPlacesInDay(tripId: tripId, dayDate: dayDate, fromIndex: fromIndex, toIndex: toIndex)
    }

    // MARK: - Delegated Methods - Date Selection

    /// Selects a date from the calendar.
    func selectDate(_ date: Date) {
        dateSelectionViewModel.selectDate(date)
    }

    /// Validates date selection.
    func validateDateSelection() -> Bool {
        dateSelectionViewModel.validate()
    }

    /// Resets date selection.
    func resetDateSelection() {
        dateSelectionViewModel.reset()
    }

    // MARK: - Delegated Methods - Drag and Drop

    /// Begins a drag operation.
    func beginDrag(placeId: String, fromDate: Date) {
        dragDropViewModel.beginDrag(placeId: placeId, fromDate: fromDate)
    }

    /// Updates drop target.
    func updateDropTarget(date: Date?) {
        dragDropViewModel.updateDropTarget(date: date)
    }

    /// Ends drag operation.
    func endDrag() {
        dragDropViewModel.endDrag()
    }

    // MARK: - Helper Methods

    /// Checks if a trip is recently created.
    func isTripRecentlyCreated(_ tripId: String) -> Bool {
        dataViewModel.isTripRecentlyCreated(tripId)
    }

    /// Clears recently created trip flag.
    func clearRecentlyCreatedTrip() {
        dataViewModel.clearRecentlyCreatedTrip()
    }

    /// Clears error and success messages.
    func clearMessages() {
        mutationsViewModel.clearMessages()
    }

    // MARK: - Reset

    /// Resets all trip data (used during logout).
    func resetAllData() {
        dataViewModel.resetAllData()
        loadingViewModel.resetLoadingStates()
        mutationsViewModel.resetAllData()
        dateSelectionViewModel.reset()
        dragDropViewModel.endDrag()
    }
}
