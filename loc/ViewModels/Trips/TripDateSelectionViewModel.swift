//
//  TripDateSelectionViewModel.swift
//  loc
//
//  ViewModel for calendar date selection in trip creation/editing.
//

import SwiftUI

/// Manages calendar date selection state for trips.
@MainActor
class TripDateSelectionViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Start date of the trip.
    @Published var startDate: Date = Date()

    /// End date of the trip.
    @Published var endDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    /// Currently selecting start or end date.
    @Published var isSelectingStartDate: Bool = true

    /// Validation error message.
    @Published var validationError: String?

    // MARK: - Computed Properties

    /// Returns whether the current date selection is valid.
    var isValid: Bool {
        startDate <= endDate
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

    /// Returns all dates in the selected range.
    var selectedDates: [Date] {
        guard isValid else { return [] }

        var dates: [Date] = []
        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }

    // MARK: - Actions

    /// Selects a date from the calendar.
    func selectDate(_ date: Date) {
        validationError = nil

        if isSelectingStartDate {
            startDate = date
            // If start date is after end date, reset end date
            if startDate > endDate {
                endDate = startDate
            }
            isSelectingStartDate = false
        } else {
            if date >= startDate {
                endDate = date
            } else {
                // User selected a date before start, make it the new start
                startDate = date
            }
            isSelectingStartDate = true
        }
    }

    /// Validates the date selection.
    func validate() -> Bool {
        if startDate > endDate {
            validationError = "End date must be after start date"
            return false
        }

        // Check for reasonable trip length (e.g., max 60 days)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        if let days = components.day, days > 60 {
            validationError = "Trip cannot exceed 60 days"
            return false
        }

        validationError = nil
        return true
    }

    /// Resets to default dates.
    func reset() {
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        isSelectingStartDate = true
        validationError = nil
    }

    /// Sets dates from an existing trip for editing.
    func setDates(from trip: Trip) {
        startDate = trip.startDate
        endDate = trip.endDate
        isSelectingStartDate = true
        validationError = nil
    }

    /// Sets dates from a lightweight trip for editing.
    func setDates(from trip: LightweightTrip) {
        startDate = trip.startDate
        endDate = trip.endDate
        isSelectingStartDate = true
        validationError = nil
    }
}
