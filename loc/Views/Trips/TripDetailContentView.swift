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

    /// Number of places assigned to a day (excludes Ideas).
    private var scheduledStopCount: Int {
        viewModel.dayIndices.reduce(0) { $0 + (viewModel.dayPlaces[$1]?.count ?? 0) }
    }

    /// Pin number + color per entry id, so overview badges match the map pins and route order.
    private var pinInfoByEntryId: [String: (number: Int, color: Color)] {
        var result: [String: (number: Int, color: Color)] = [:]
        for annotation in viewModel.buildTripAnnotations() {
            result[annotation.id] = (number: annotation.stopNumber, color: annotation.color)
        }
        return result
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    /// Day-by-day stop list, in the same order as the map route.
    private var itinerarySection: some View {
        let pinInfo = pinInfoByEntryId
        return VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Itinerary")

            ForEach(viewModel.dayIndices, id: \.self) { dayIndex in
                let places = viewModel.dayPlaces[dayIndex] ?? []
                let nextId = viewModel.nextStopId(dayIndex: dayIndex)
                if !places.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            viewModel.selectedDayForDetail = dayIndex
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(TripMapViewModel.colorForDay(dayIndex))
                                    .frame(width: 8, height: 8)
                                Text(viewModel.dayLabel(for: dayIndex))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text("· \(places.count) stop\(places.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 8)

                        ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                            if index > 0 {
                                insertDivider(dayIndex: dayIndex, afterEntryId: places[index - 1].id)
                            }
                            stopRow(
                                place: place,
                                dayIndex: dayIndex,
                                isFirst: index == 0,
                                isLast: index == places.count - 1
                            ) {
                            TripPlaceRowView(
                                place: place,
                                number: pinInfo[place.id]?.number,
                                badgeColor: pinInfo[place.id]?.color ?? TripMapViewModel.colorForDay(dayIndex),
                                onTap: {
                                    viewModel.selectedPlaceIdForDetail = place.placeId
                                },
                                isNext: place.id == nextId,
                                onToggleVisited: viewModel.canEdit ? {
                                    viewModel.toggleVisited(entryId: place.id)
                                } : nil
                            )
                            }
                        }

                        if viewModel.canEdit, let lastId = places.last?.id {
                            Button {
                                viewModel.requestInsert(dayIndex: dayIndex, afterEntryId: lastId)
                            } label: {
                                Label("Add stop", systemImage: "plus.circle")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.mesaAccent)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 36)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    /// Divider between two stops with a small "+" to insert a stop there (editors only).
    @ViewBuilder
    private func insertDivider(dayIndex: Int, afterEntryId: String) -> some View {
        if viewModel.canEdit {
            HStack(spacing: 6) {
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
                Button {
                    viewModel.requestInsert(dayIndex: dayIndex, afterEntryId: afterEntryId)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.mesaAccent.opacity(0.85))
                        .frame(width: 28, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add stop here")
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
            }
            .padding(.leading, 36)
        } else {
            Divider().padding(.leading, 36)
        }
    }

    /// Wraps a stop row with drag-to-reorder (drop onto a row = place before it) and a context menu.
    @ViewBuilder
    private func stopRow<Content: View>(
        place: TripDayPlace,
        dayIndex: Int,
        isFirst: Bool,
        isLast: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if viewModel.canEdit {
            content()
                .draggable(place.id) {
                    TripPlaceDragPreview()
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let droppedId = items.first, droppedId != place.id else { return false }
                    Task {
                        await viewModel.moveStop(entryId: droppedId, toDayIndex: dayIndex, beforeEntryId: place.id)
                    }
                    return true
                }
                .contextMenu {
                    Button {
                        viewModel.requestInsert(dayIndex: dayIndex, afterEntryId: place.id)
                    } label: {
                        Label("Add stop after", systemImage: "plus")
                    }
                    if !isFirst {
                        Button {
                            viewModel.moveStop(entryId: place.id, by: -1)
                        } label: {
                            Label("Move up", systemImage: "arrow.up")
                        }
                    }
                    if !isLast {
                        Button {
                            viewModel.moveStop(entryId: place.id, by: 1)
                        } label: {
                            Label("Move down", systemImage: "arrow.down")
                        }
                    }
                    Button {
                        viewModel.toggleVisited(entryId: place.id)
                    } label: {
                        Label(place.isVisited ? "Mark not visited" : "Mark visited", systemImage: "checkmark.circle")
                    }
                }
        } else {
            content()
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TripDetailHeaderView(
                    trip: trip,
                    collaborators: viewModel.collaborators,
                    stopCount: scheduledStopCount
                )

                if scheduledStopCount > 0 {
                    itinerarySection
                    Divider()
                        .padding(.vertical, 8)
                }

                sectionTitle("Calendar")

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
        .sheet(item: $viewModel.insertRequest, onDismiss: {
            Task { await viewModel.completePendingInsert() }
        }) { request in
            if let userId = ServiceContainer.shared.authService.currentUserId {
                AddPlaceToTripSheet(
                    tripId: trip.id,
                    targetDayIndex: request.dayIndex,
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
                    tripId: trip.id,
                    targetDayIndex: nil,
                    existingPlaceIds: viewModel.allPlaceIdsInTrip,
                    userId: userId
                )
            }
        }
    }
}
