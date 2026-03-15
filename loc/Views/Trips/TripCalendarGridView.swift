//
//  TripCalendarGridView.swift
//  loc
//
//  7-column calendar grid showing the trip's date range with place indicators
//

import SwiftUI

/// Displays a compact weekday-aligned calendar grid for a trip's date range.
struct TripCalendarGridView: View {
    let calendarData: CalendarGridData
    let dayPlaces: [Int: [TripDayPlace]]
    let onDayTap: (Int) -> Void
    let onDropPlace: ((String, Int) -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 4) {
            weekdayHeaderRow
            calendarGrid
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Weekday Headers

    /// Row of abbreviated weekday labels (S, M, T, ...).
    private var weekdayHeaderRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(CalendarGridData.weekdayHeaders.enumerated()), id: \.offset) { _, header in
                Text(header)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    /// Grid of day cells with colored dots and drop targets.
    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(calendarData.cells) { cell in
                TripCalendarDayCellView(
                    cell: cell,
                    dotColors: buildDotColors(dayIndex: cell.dayIndex, dayPlaces: dayPlaces),
                    onTap: {
                        if let dayIndex = cell.dayIndex {
                            onDayTap(dayIndex)
                        }
                    },
                    onDropPlace: onDropPlace.map { handler in
                        { placeId in
                            if let dayIndex = cell.dayIndex {
                                handler(placeId, dayIndex)
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Helpers

/// Builds gradient-shaded dot colors for a calendar cell's assigned places.
private func buildDotColors(dayIndex: Int?, dayPlaces: [Int: [TripDayPlace]]) -> [Color] {
    guard let dayIndex = dayIndex else { return [] }
    let count = dayPlaces[dayIndex]?.count ?? 0
    guard count > 0 else { return [] }

    let dotCount = min(count, 3)
    return (0..<dotCount).map { stopIndex in
        TripMapViewModel.colorForStop(
            dayIndex: dayIndex,
            stopIndex: stopIndex,
            totalStops: dotCount
        )
    }
}
