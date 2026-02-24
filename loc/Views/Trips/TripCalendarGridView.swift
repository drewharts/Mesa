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

    private var weekdayHeaderRow: some View {
        HStack(spacing: 4) {
            ForEach(CalendarGridData.weekdayHeaders, id: \.self) { header in
                Text(header)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(calendarData.cells) { cell in
                TripCalendarDayCellView(
                    cell: cell,
                    placeCount: cell.dayIndex.flatMap { dayPlaces[$0]?.count } ?? 0,
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
