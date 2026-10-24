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
    let isEditing: Bool
    let travelTimeSegments: [String: TripTravelTimeSegment]
    let onMove: (IndexSet, Int) -> Void
    let onDelete: (String) -> Void
    let onPlaceTap: (String) -> Void
    var nextStopId: String? = nil
    var onToggleVisited: ((String) -> Void)? = nil
    var onInsertAfter: ((String) -> Void)? = nil
    var onMoveBy: ((String, Int) -> Void)? = nil

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
                VStack(spacing: 0) {
                    if index > 0 {
                        let prev = places[index - 1]
                        TripTravelTimeConnectorView(
                            segment: travelTimeSegments["\(prev.placeId)->\(place.placeId)"]
                        )
                    }
                    TripDayPlaceCard(
                        place: place,
                        number: index + 1,
                        onTap: { onPlaceTap(place.placeId) },
                        isNext: place.id == nextStopId,
                        onToggleVisited: (canEdit && onToggleVisited != nil) ? { onToggleVisited?(place.id) } : nil
                    )
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .draggable(place.id) {
                    TripPlaceDragPreview()
                }
                .contextMenu {
                    if canEdit {
                        if let onInsertAfter {
                            Button {
                                onInsertAfter(place.id)
                            } label: {
                                Label("Add stop after", systemImage: "plus")
                            }
                        }
                        if let onMoveBy {
                            if index > 0 {
                                Button {
                                    onMoveBy(place.id, -1)
                                } label: {
                                    Label("Move up", systemImage: "arrow.up")
                                }
                            }
                            if index < places.count - 1 {
                                Button {
                                    onMoveBy(place.id, 1)
                                } label: {
                                    Label("Move down", systemImage: "arrow.down")
                                }
                            }
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if canEdit, let onToggleVisited {
                        Button {
                            onToggleVisited(place.id)
                        } label: {
                            Label(place.isVisited ? "Unvisit" : "Visited",
                                  systemImage: place.isVisited ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(Color.mesaAccent)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if canEdit {
                        Button {
                            onDelete(place.id)
                        } label: {
                            Label("Ideas", systemImage: "lightbulb")
                        }
                        .tint(.orange)
                    }
                }
            }
            .onMove(perform: canEdit ? onMove : nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
    }
}
