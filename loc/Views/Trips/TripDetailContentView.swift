//
//  TripDetailContentView.swift
//  loc
//
//  Split-screen layout: calendar grid on top, place source on bottom
//

import SwiftUI

/// Displays the trip header, calendar grid, and inline place source for drag-to-add.
struct TripDetailContentView: View {
    let trip: Trip
    @ObservedObject var viewModel: TripDetailViewModel

    private var calendarData: CalendarGridData {
        CalendarGridData(trip: trip)
    }

    var body: some View {
        VStack(spacing: 0) {
            TripDetailHeaderView(trip: trip, collaborators: viewModel.collaborators)

            TripCalendarGridView(
                calendarData: calendarData,
                dayPlaces: viewModel.dayPlaces,
                onDayTap: { dayIndex in
                    viewModel.selectedDayForDetail = dayIndex
                },
                onDropPlace: viewModel.canEdit ? { placeId, dayIndex in
                    Task { await viewModel.addPlaceToSpecificDay(placeId: placeId, dayIndex: dayIndex) }
                } : nil
            )

            Divider()

            if viewModel.canEdit {
                TripPlaceSourceView(tripViewModel: viewModel)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}
