//
//  TripDetailContentView.swift
//  loc
//
//  Trip detail layout: calendar grid on top, ideas tiles below
//

import SwiftUI

/// Displays the trip header, calendar grid, and Ideas section for drag-to-add.
struct TripDetailContentView: View {
    let trip: Trip
    @ObservedObject var viewModel: TripDetailViewModel

    @State private var showAddPlaceSheet = false

    /// Calendar layout data computed from the trip's date range.
    private var calendarData: CalendarGridData {
        CalendarGridData(trip: trip)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TripDetailHeaderView(trip: trip, collaborators: viewModel.collaborators)

                TripCalendarGridView(
                    calendarData: calendarData,
                    dayPlaces: viewModel.dayPlaces,
                    onDayTap: { dayIndex in
                        viewModel.selectedDayForDetail = dayIndex
                    },
                    onDropPlace: viewModel.canEdit ? { droppedId, dayIndex in
                        viewModel.handleCalendarDrop(droppedId: droppedId, dayIndex: dayIndex)
                    } : nil
                )

                if viewModel.canEdit {
                    Divider()
                    TripIdeasSectionView(
                        ideaPlaces: viewModel.ideaPlaces,
                        onRemove: { entryId in
                            Task { await viewModel.removeIdea(entryId: entryId) }
                        },
                        onAddPlace: { showAddPlaceSheet = true },
                        onPlaceTap: { placeId in
                            viewModel.selectedPlaceIdForDetail = placeId
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showAddPlaceSheet, onDismiss: {
            Task { await viewModel.loadTrip() }
        }) {
            if let userId = ServiceContainer.shared.authService.currentUserId {
                AddPlaceToTripSheet(
                    tripId: trip.id,
                    targetDayIndex: nil,
                    existingPlaceIds: viewModel.allPlaceIdsInTrip,
                    userId: userId
                )
            }
        }
    }
}
