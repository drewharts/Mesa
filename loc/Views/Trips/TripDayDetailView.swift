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

    private var places: [TripDayPlace] {
        viewModel.dayPlaces[dayIndex] ?? []
    }

    var body: some View {
        TripDayItineraryView(
            places: places,
            canEdit: viewModel.canEdit,
            isEditing: isEditing,
            onMove: { fromOffsets, toOffset in
                viewModel.reorderPlaces(dayIndex: dayIndex, fromOffsets: fromOffsets, toOffset: toOffset)
            },
            onDelete: { entryId in
                Task { await viewModel.removePlaceFromDay(entryId: entryId) }
            },
            onPlaceTap: { placeId in
                viewModel.highlightTripAnnotation(placeId: placeId)
                selectedPlaceId = placeId
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
            PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
        }
        .sheet(isPresented: $showAddPlaceSheet) {
            if let userId = ServiceContainer.shared.authService.currentUserId {
                AddPlaceToTripSheet(
                    tripId: viewModel.tripId,
                    targetDayIndex: dayIndex,
                    existingPlaceIds: viewModel.allPlaceIdsInTrip,
                    userId: userId,
                    onDismiss: {
                        Task { await viewModel.loadTrip() }
                    }
                )
            }
        }
    }
}
