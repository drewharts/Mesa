//
//  DateRangeCalendarView.swift
//  loc
//
//  Inline calendar view for selecting a date range with month navigation
//

import SwiftUI

/// Displays a full-month calendar grid with date range selection and month navigation.
struct DateRangeCalendarView: View {
    @ObservedObject var viewModel: DateRangePickerViewModel

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            monthNavigationHeader
            Divider()
            weekdayHeaderRow
            Divider()
            calendarWeeks
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Month Navigation Header

    private var monthNavigationHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(viewModel.abbreviatedMonthLabel)
                .font(.title.bold())

            Text(viewModel.yearLabel)
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 24) {
                Button(action: viewModel.retreatMonth) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Button(action: viewModel.advanceMonth) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Weekday Headers

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Weeks

    private var calendarWeeks: some View {
        let weeks = viewModel.weeksForDisplayedMonth()
        return VStack(spacing: 0) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                weekRow(week)

                if index < weeks.count - 1 {
                    Divider()
                }
            }
        }
    }

    /// Renders a single week row as an HStack of day cells.
    private func weekRow(_ week: [DayCell]) -> some View {
        HStack(spacing: 0) {
            ForEach(week) { cell in
                DateRangeDayCellView(
                    cell: cell,
                    visualState: viewModel.visualState(for: cell.date),
                    onTap: {
                        if let date = cell.date {
                            viewModel.handleDayTap(date)
                        }
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}
