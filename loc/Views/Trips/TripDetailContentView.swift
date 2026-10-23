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
                                Divider().padding(.leading, 36)
                            }
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
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
