//
//  TripDayView.swift
//  loc
//
//  View for a single day in the trip planning interface.
//

import SwiftUI

/// Displays a single day in the trip with its assigned places.
struct TripDayView: View {
    let date: Date
    let dayNumber: Int
    let places: [TripPlaceItem]
    let onAddPlace: () -> Void
    let onRemovePlace: (String) -> Void
    let onReorderPlaces: (Int, Int) -> Void

    @State private var editMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayHeaderView
            Divider()
            placesListView
        }
        .background(Color.white)
    }

    /// Day header with day number, date, and add button.
    private var dayHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(dayNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 12) {
                if !places.isEmpty {
                    Button(action: { editMode.toggle() }) {
                        Text(editMode ? "Done" : "Edit")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                Button(action: onAddPlace) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.02))
    }

    /// List of places for this day or empty state.
    @ViewBuilder
    private var placesListView: some View {
        if places.isEmpty {
            emptyStateView
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, item in
                    TripPlaceRow(
                        item: item,
                        isEditing: editMode,
                        onRemove: { onRemovePlace(item.placeId) }
                    )

                    if index < places.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
                .onMove { source, destination in
                    guard let fromIndex = source.first else { return }
                    onReorderPlaces(fromIndex, destination > fromIndex ? destination - 1 : destination)
                }
            }
        }
    }

    /// Empty state when no places for this day.
    private var emptyStateView: some View {
        Button(action: onAddPlace) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Add a place")
                    .font(.subheadline)
                    .foregroundColor(.blue)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    /// Formatted date string for display.
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
