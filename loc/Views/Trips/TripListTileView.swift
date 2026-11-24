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

    /// Square list cover: user image, else place photos, else the generated placeholder.
    private var collageImage: some View {
        Group {
            ListCoverCollage(
                previewPhotos: list.preview_photos,
                places: Array(previewPlaces.prefix(3)),
                placeColors: $placeColors,
                seed: list.list_id,
                listName: list.name,
                userImageURL: list.image
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
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
