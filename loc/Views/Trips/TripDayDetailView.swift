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

    private var places: [TripDayPlace] {
        viewModel.dayPlaces[dayIndex] ?? []
    }

    var body: some View {
        TripDayItineraryView(
            places: places,
            canEdit: viewModel.canEdit,
            onMove: { fromOffsets, toOffset in
                viewModel.reorderPlaces(dayIndex: dayIndex, fromOffsets: fromOffsets, toOffset: toOffset)
            },
            onDelete: { entryId in
                Task { await viewModel.removePlaceFromDay(entryId: entryId) }
            }
        )
        .navigationTitle(viewModel.dayLabel(for: dayIndex))
        .navigationBarTitleDisplayMode(.inline)
    }
}
