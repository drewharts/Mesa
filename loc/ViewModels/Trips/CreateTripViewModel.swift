//
//  CreateTripViewModel.swift
//  loc
//
//  ViewModel for creating a new trip.
//

import SwiftUI

/// Manages state and logic for trip creation.
@MainActor
class CreateTripViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var tripName: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @Published var showingCalendar: Bool = false
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private weak var tripsViewModel: ProfileTripsViewModel?

    // MARK: - Initialization

    /// Initializes the ViewModel with a reference to the parent trips ViewModel.
    init(tripsViewModel: ProfileTripsViewModel?) {
        self.tripsViewModel = tripsViewModel
    }

    // MARK: - Computed Properties

    /// Whether the create button should be enabled.
    var canCreate: Bool {
        !tripName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Returns the number of days in the selected range.
    var numberOfDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }

    /// Returns a formatted date range string.
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)
        let currentYear = calendar.component(.year, from: Date())

        if startYear == endYear && startYear == currentYear {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }

    // MARK: - Public Methods

    /// Creates the trip and returns success status.
    func createTrip() async -> Bool {
        guard canCreate else { return false }

        isCreating = true

        if let _ = await tripsViewModel?.createTrip(
            name: tripName.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate
        ) {
            isCreating = false
            return true
        } else {
            errorMessage = tripsViewModel?.errorMessage ?? "Failed to create trip"
            isCreating = false
            return false
        }
    }

    /// Opens the calendar picker.
    func openCalendar() {
        showingCalendar = true
    }

    /// Clears the error message.
    func clearError() {
        errorMessage = nil
    }

    /// Sets the trips ViewModel reference (called from onAppear).
    func setTripsViewModel(_ viewModel: ProfileTripsViewModel?) {
        self.tripsViewModel = viewModel
    }
}
