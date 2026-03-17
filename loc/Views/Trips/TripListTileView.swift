//
//  TripListTileView.swift
//  loc
//
//  Tile for a user's list showing photo collage, name, and place count.
//

import SwiftUI

/// Tile for a user's list showing photo collage, name, and place count.
struct TripListTileView: View {
    let list: LightweightPlaceList
    let previewPlaces: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            collageImage
            listInfo
        }
    }

    /// Square photo collage with fallback for empty lists.
    private var collageImage: some View {
        Group {
            if !previewPlaces.isEmpty {
                ListPhotoCollage(
                    places: Array(previewPlaces.prefix(3)),
                    placeColors: $placeColors
                )
            } else {
                emptyListFallback
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    /// Fallback view when list has no preview places.
    private var emptyListFallback: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundStyle(.gray.opacity(0.5))
            Text("No places yet")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    /// List name and place count text.
    private var listInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(list.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(list.place_count) place\(list.place_count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
