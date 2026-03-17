//
//  TripIdeasSectionView.swift
//  loc
//
//  "Ideas" section in trip detail showing unassigned places as draggable tiles
//

import SwiftUI

/// Displays unassigned Ideas places as a 2-column tile grid that can be dragged to calendar days.
struct TripIdeasSectionView: View {
    let ideaPlaces: [TripDayPlace]
    let onRemove: (String) -> Void
    var onAddPlace: (() -> Void)?
    var onPlaceTap: ((String) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader
            if !ideaPlaces.isEmpty {
                Label("Drag to a day on the calendar", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ideasGrid
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Header

    /// Section header with lightbulb icon, "Ideas" label, and count badge.
    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Ideas")
                .font(.subheadline)
                .fontWeight(.semibold)

            if !ideaPlaces.isEmpty {
                Text("\(ideaPlaces.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary))
            }

            Spacer()

            if let onAddPlace {
                Button(action: onAddPlace) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Ideas Grid

    /// Displays idea tiles in a 2-column grid, or an empty state message.
    @ViewBuilder
    private var ideasGrid: some View {
        if ideaPlaces.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ideaPlaces) { place in
                    ZStack(alignment: .topTrailing) {
                        PopupPlaceCard(
                            place: place.asLightweightPlace,
                            preferExternalThumbnail: false,
                            onNavigate: onPlaceTap
                        )

                        Button(action: { onRemove(place.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        .padding(6)
                    }
                    .draggable(place.id) {
                        TripPlaceDragPreview(placeName: place.placeName ?? "Place")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    /// Message shown when no ideas have been saved to the trip.
    private var emptyState: some View {
        Text("Save places to this trip and organize them later")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
