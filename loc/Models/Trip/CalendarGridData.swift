//
//  CalendarGridData.swift
//  loc
//
//  Pure data struct that computes calendar cell layout from a Trip's date range
//

import Foundation

/// Computes a weekday-aligned calendar grid for a trip's date range.
struct CalendarGridData {
    struct Cell: Identifiable {
        let id: Int          // flat index in the grid
        let dayIndex: Int?   // nil = empty padding cell
        let dayOfMonth: Int? // e.g. 5, 6, 7
        let date: Date?
    }

    static let weekdayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
    let cells: [Cell]

    /// Builds the calendar grid cells from a trip's start date and number of days.
    init(trip: Trip) {
        // trip.startDate is a UTC-midnight anchor (see Trip.parseDate); must use Trip.utcCalendar
        // here, not Calendar.current, or every day number/weekday shifts by one for non-UTC devices.
        let calendar = Trip.utcCalendar
        let startDate = trip.startDate
        let numberOfDays = trip.numberOfDays

        // Weekday: 1 = Sunday, 7 = Saturday
        let startWeekday = calendar.component(.weekday, from: startDate)
        let leadingEmpties = startWeekday - 1

        var result: [Cell] = []
        var flatIndex = 0

        // Leading empty cells for weekday alignment
        for _ in 0..<leadingEmpties {
            result.append(Cell(id: flatIndex, dayIndex: nil, dayOfMonth: nil, date: nil))
            flatIndex += 1
        }

        // Real day cells
        for dayIndex in 0..<numberOfDays {
            let date = calendar.date(byAdding: .day, value: dayIndex, to: startDate)
            let dayOfMonth = date.map { calendar.component(.day, from: $0) }
            result.append(Cell(id: flatIndex, dayIndex: dayIndex, dayOfMonth: dayOfMonth, date: date))
            flatIndex += 1
        }

        // Trailing empty cells to complete the last row
        let remainder = result.count % 7
        if remainder != 0 {
            let trailingEmpties = 7 - remainder
            for _ in 0..<trailingEmpties {
                result.append(Cell(id: flatIndex, dayIndex: nil, dayOfMonth: nil, date: nil))
                flatIndex += 1
            }
        }

        self.cells = result
    }
}
