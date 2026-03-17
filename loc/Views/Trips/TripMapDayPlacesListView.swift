//
//  TripMapDayPlacesListView.swift
//  loc
//
//  Scrollable place list for the trip map sheet, grouped by day
//

import SwiftUI

/// Lists trip places in the map sheet, grouped by day in "All" mode or flat for a single day.
struct TripMapDayPlacesListView: View {
    @ObservedObject var viewModel: TripMapViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.selectedDayFilter == nil {
                        allDaysContent
                    } else {
                        singleDayContent
                    }
                }
            }
            .onChange(of: viewModel.selectedAnnotationId) { _, newId in
                guard let newId else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }

    /// All days grouped with section headers.
    private var allDaysContent: some View {
        ForEach(viewModel.dayIndices, id: \.self) { dayIndex in
            let dayAnnotations = viewModel.annotations.filter { $0.dayIndex == dayIndex }
            if !dayAnnotations.isEmpty {
                TripMapDaySectionHeaderView(
                    dayIndex: dayIndex,
                    dayColor: TripMapViewModel.colorForDay(dayIndex),
                    label: viewModel.dayLabel(for: dayIndex)
                )
                ForEach(dayAnnotations) { annotation in
                    TripMapPlaceRowView(
                        annotation: annotation,
                        isSelected: viewModel.selectedAnnotationId == annotation.id,
                        onTap: {
                            viewModel.selectAnnotation(annotation.id)
                            viewModel.selectedPlaceIdForDetail = annotation.placeId
                        }
                    )
                    .id(annotation.id)
                }
            }
        }
    }

    /// Single day flat list.
    private var singleDayContent: some View {
        Group {
            let dayAnnotations = viewModel.annotations
            if dayAnnotations.isEmpty {
                emptyState
            } else {
                ForEach(dayAnnotations) { annotation in
                    TripMapPlaceRowView(
                        annotation: annotation,
                        isSelected: viewModel.selectedAnnotationId == annotation.id,
                        onTap: {
                            viewModel.selectAnnotation(annotation.id)
                            viewModel.selectedPlaceIdForDetail = annotation.placeId
                        }
                    )
                    .id(annotation.id)
                }
            }
        }
    }

    /// Empty state for days with no places.
    private var emptyState: some View {
        Text("No places with coordinates for this day")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
    }
}
