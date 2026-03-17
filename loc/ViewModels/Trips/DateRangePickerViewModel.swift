//
//  DateRangePickerViewModel.swift
//  loc
//
//  Child ViewModel for inline calendar range selection in trip creation
//  Single Responsibility: Date range selection state machine and calendar grid computation
//

import Foundation
import Combine

// MARK: - Supporting Types

/// Represents the current selection state of the date range picker.
enum DateRangeSelectionState: Equatable {
    case empty
    case startOnly(Date)
    case complete(start: Date, end: Date)
}

/// Represents a single cell in the calendar grid.
struct DayCell: Identifiable {
    let id: String
    let date: Date?
    let dayOfMonth: Int?
    let isCurrentMonth: Bool

    /// Creates a placeholder cell for leading/trailing padding.
    static func placeholder(id: String) -> DayCell {
        DayCell(id: id, date: nil, dayOfMonth: nil, isCurrentMonth: false)
    }
}

/// Visual state for rendering a day cell.
enum DayCellVisualState {
    case unselected
    case startDate
    case endDate
    case inRange
    case disabled
    case placeholder
}

@MainActor
class DateRangePickerViewModel: ObservableObject {
    // MARK: - Published State

    @Published var displayedMonth: Date
    @Published var selectionState: DateRangeSelectionState

    // MARK: - Private

    private let calendar = Calendar.current

    // MARK: - Initialization

    /// Initializes with optional default start and end dates.
    init(startDate: Date? = nil, endDate: Date? = nil) {
        let today = Date()
        let start = startDate ?? today
        self.displayedMonth = calendar.startOfMonth(for: start)

        if let startDate, let endDate {
            let normalizedStart = calendar.startOfDay(for: startDate)
            let normalizedEnd = calendar.startOfDay(for: endDate)
            self.selectionState = .complete(start: normalizedStart, end: normalizedEnd)
        } else if let startDate {
            self.selectionState = .startOnly(calendar.startOfDay(for: startDate))
        } else {
            self.selectionState = .empty
        }
    }

    // MARK: - Month Navigation

    /// Advances the displayed month by one.
    func advanceMonth() {
        if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = next
        }
    }

    /// Retreats the displayed month by one.
    func retreatMonth() {
        if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = prev
        }
    }

    /// Formatted label for the displayed month, e.g. "February 2026".
    var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    /// Abbreviated month label, e.g. "Mar".
    var abbreviatedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: displayedMonth)
    }

    /// Year label for the displayed month, e.g. "2026".
    var yearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: displayedMonth)
    }

    // MARK: - Day Tap Handling

    /// Processes a day tap according to the selection state machine.
    func handleDayTap(_ date: Date) {
        let tapped = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        guard tapped >= today else { return }

        switch selectionState {
        case .empty:
            selectionState = .startOnly(tapped)

        case .startOnly(let start):
            if tapped == start {
                selectionState = .empty
            } else if tapped > start {
                selectionState = .complete(start: start, end: tapped)
            } else {
                selectionState = .startOnly(tapped)
            }

        case .complete:
            selectionState = .startOnly(tapped)
        }
    }

    // MARK: - Grid Computation

    /// Computes the cell grid for the displayed month, padded to full week rows.
    func cellsForDisplayedMonth() -> [DayCell] {
        let firstOfMonth = displayedMonth
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingPadding = weekday - calendar.firstWeekday
        let adjustedPadding = (leadingPadding + 7) % 7

        guard let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        var cells: [DayCell] = []

        // Leading placeholder cells
        for i in 0..<adjustedPadding {
            cells.append(.placeholder(id: "lead-\(i)"))
        }

        // Day cells for the month
        for day in range {
            guard let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth) else {
                continue
            }
            let normalized = calendar.startOfDay(for: date)
            cells.append(DayCell(
                id: "day-\(day)",
                date: normalized,
                dayOfMonth: day,
                isCurrentMonth: true
            ))
        }

        // Trailing placeholder cells to fill to next multiple of 7
        let remainder = cells.count % 7
        if remainder > 0 {
            let remaining = 7 - remainder
            for i in 0..<remaining {
                cells.append(.placeholder(id: "trail-\(i)"))
            }
        }

        return cells
    }

    /// Chunks the flat cell array into rows of 7 for week-based layout.
    func weeksForDisplayedMonth() -> [[DayCell]] {
        let cells = cellsForDisplayedMonth()
        return stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }
    }

    /// Determines the visual state of a cell for the given date.
    func visualState(for date: Date?) -> DayCellVisualState {
        guard let date else { return .placeholder }

        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        if day < today {
            return .disabled
        }

        switch selectionState {
        case .empty:
            return .unselected

        case .startOnly(let start):
            return day == start ? .startDate : .unselected

        case .complete(let start, let end):
            if day == start { return .startDate }
            if day == end { return .endDate }
            if day > start && day < end { return .inRange }
            return .unselected
        }
    }

    // MARK: - Reset

    /// Resets selection to empty and displayed month to today.
    func reset() {
        selectionState = .empty
        displayedMonth = calendar.startOfMonth(for: Date())
    }
}

// MARK: - Calendar Extension

private extension Calendar {
    /// Returns the first day of the month for the given date.
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
