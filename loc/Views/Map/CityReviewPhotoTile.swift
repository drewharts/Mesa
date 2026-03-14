//
//  CityReviewPhotoTile.swift
//  loc
//
//  Tile view for a review photo in the city detail horizontal scroll row.
//

import SwiftUI

/// Square tile displaying a review photo with place name and reviewer overlay.
struct CityReviewPhotoTile: View {
    let photo: CityReviewPhoto
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                background

                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.placeName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(photo.reviewerFirstName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(10)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    /// Image background with gradient or camera icon placeholder.
    @ViewBuilder
    private var background: some View {
        if let url = URL(string: photo.imageUrl) {
            GeometryReader { geometry in
                CachedAsyncImage(url: url, targetSize: geometry.size) {
                    iconPlaceholder
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(gradientOverlay)
            }
        } else {
            iconPlaceholder
        }
    }

    /// Gradient overlay for image backgrounds.
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Camera icon placeholder shown when image URL is invalid.
    private var iconPlaceholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .overlay(
                Image(systemName: "camera.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            )
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
