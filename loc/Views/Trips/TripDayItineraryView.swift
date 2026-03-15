//
//  TripDayItineraryView.swift
//  loc
//
//  Itinerary list for a single day with drag-to-reorder and delete
//

import SwiftUI

/// Displays the ordered list of places for one day, with reorder and delete support.
struct TripDayItineraryView: View {
    let places: [TripDayPlace]
    let canEdit: Bool
    let onMove: (IndexSet, Int) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        if places.isEmpty {
            emptyDayState
        } else {
            placesList
        }
    }

    // MARK: - Empty State

    private var emptyDayState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No places for this day")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Tap + to add places")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Places List

    private var placesList: some View {
        List {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                TripTimelinePlaceCard(
                    place: place,
                    number: index + 1,
                    isFirst: index == 0,
                    isLast: index == places.count - 1
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                .draggable(place.id) {
                    TripPlaceDragPreview(placeName: place.placeName ?? "Place")
                }
            }
            .onMove(perform: canEdit ? onMove : nil)
            .onDelete(perform: canEdit ? { indexSet in
                for index in indexSet {
                    onDelete(places[index].id)
                }
            } : nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, canEdit ? .constant(.active) : .constant(.inactive))
    }
}
