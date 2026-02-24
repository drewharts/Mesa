//
//  TripDraggableMapPlaceRow.swift
//  loc
//
//  Compact draggable row for a place in the map-based place picker list
//

import SwiftUI

/// Compact place row with drag support for the map place picker list.
struct TripDraggableMapPlaceRow: View {
    let place: LightweightPlace
    let isAlreadyAdded: Bool
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            placeThumbnail
            placeInfo
            Spacer()
            statusIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .opacity(isAlreadyAdded ? 0.6 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .draggable(place.place_id) {
            TripPlaceDragPreview(placeName: place.name)
        }
    }

    // MARK: - Thumbnail

    private var placeThumbnail: some View {
        Group {
            if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderRect
                }
            } else {
                placeholderRect
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "mappin")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - Place Info

    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        Group {
            if isAlreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
            } else {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
    }
}
