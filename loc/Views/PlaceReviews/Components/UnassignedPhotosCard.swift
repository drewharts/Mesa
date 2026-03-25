//  UnassignedPhotosCard.swift
//  loc
//
//  DUMB Component: Card showing photos without GPS data that can be assigned to clusters.
//  Single Responsibility: Render unassigned photo thumbnails with tap-to-assign action.

import SwiftUI

struct UnassignedPhotosCard: View {
    let thumbnails: [UIImage]
    let onTapThumbnail: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            thumbnailRow
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                Text("Unassigned")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Spacer()

            Text("\(thumbnails.count) photo\(thumbnails.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var thumbnailRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { offset, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                        )
                        .onTapGesture {
                            onTapThumbnail(offset)
                        }
                }
            }
        }
    }
}
