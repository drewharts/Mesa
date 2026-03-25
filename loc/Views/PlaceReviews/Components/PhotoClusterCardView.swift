//  PhotoClusterCardView.swift
//  loc
//
//  DUMB Component: Displays a single photo cluster card with thumbnails and review status.
//  Single Responsibility: Render cluster info and photo thumbnails for the overview screen.

import SwiftUI

struct PhotoClusterCardView: View {
    let addressHint: String
    let photoCount: Int
    let thumbnails: [UIImage]
    let isReviewed: Bool
    let isLoading: Bool
    let onTap: () -> Void
    let onLongPressThumbnail: (Int) -> Void

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                thumbnailRow
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(mesaCharcoal)
                    .font(.system(size: 18))

                Text(addressHint)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            statusIndicator
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isLoading {
            ProgressView()
                .scaleEffect(0.7)
        } else if isReviewed {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
        } else {
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    private var thumbnailRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(thumbnails.prefix(8).enumerated()), id: \.offset) { offset, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onLongPressGesture {
                            onLongPressThumbnail(offset)
                        }
                }
            }
        }
    }
}
