//
//  TripDayDetailView.swift
//  loc
//
//  Full-screen day itinerary view navigated to from the calendar grid
//

import SwiftUI

/// Displays the itinerary for a single trip day with reorder and delete support.
struct TripDayDetailView: View {
    @ObservedObject var viewModel: TripDetailViewModel
    let dayIndex: Int

    @State private var showAddPlaceSheet = false
    @State private var isEditing = false
    @State private var selectedPlaceId: String?
    @State private var showInsertSheet = false

    private var places: [TripDayPlace] {
        viewModel.dayPlaces[dayIndex] ?? []
    }

    var body: some View {
        TripDayItineraryView(
            places: places,
            canEdit: viewModel.canEdit,
            isEditing: isEditing,
            travelTimeSegments: viewModel.travelTimesViewModel.segments,
            onMove: { fromOffsets, toOffset in
                viewModel.reorderPlaces(dayIndex: dayIndex, fromOffsets: fromOffsets, toOffset: toOffset)
            },
            onDelete: { entryId in
                Task { await viewModel.removePlaceFromDay(entryId: entryId) }
            },
            onPlaceTap: { placeId in
                viewModel.highlightTripAnnotation(placeId: placeId)
                selectedPlaceId = placeId
            },
            nextStopId: viewModel.nextStopId(dayIndex: dayIndex),
            onToggleVisited: { entryId in
                viewModel.toggleVisited(entryId: entryId)
            },
            onInsertAfter: { entryId in
                viewModel.requestInsert(dayIndex: dayIndex, afterEntryId: entryId, presentFromOverview: false)
                showInsertSheet = true
            },
            onMoveBy: { entryId, offset in
                viewModel.moveStop(entryId: entryId, by: offset)
            }
        )
        .navigationTitle(viewModel.dayLabel(for: dayIndex))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canEdit {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Done" : "Reorder") {
                        withAnimation { isEditing.toggle() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPlaceSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .navigationDestination(item: $selectedPlaceId) { placeId in
            // Map camera is driven by the trip pin highlight (avoids a double camera jump)
            PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: false)
        }
        .sheet(isPresented: $showInsertSheet, onDismiss: {
            Task { await viewModel.completePendingInsert() }
        }) {
            if let userId = ServiceContainer.shared.authService.currentUserId {
                AddPlaceToTripSheet(
                    tripId: viewModel.tripId,
                    targetDayIndex: dayIndex,
                    existingPlaceIds: viewModel.allPlaceIdsInTrip,
                    userId: userId
                )
            }
        }
        .sheet(isPresented: $showAddPlaceSheet, onDismiss: {
            Task { await viewModel.loadTrip() }
        }) {
            if let userId = ServiceContainer.shared.authService.currentUserId {
                AddPlaceToTripSheet(
                    tripId: viewModel.tripId,
                    targetDayIndex: dayIndex,
                    existingPlaceIds: viewModel.allPlaceIdsInTrip,
                    userId: userId
                )
            }
        }
    }
}
