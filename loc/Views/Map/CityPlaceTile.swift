//
//  CityPlaceTile.swift
//  loc
//
//  Tile view for a place in the city detail horizontal scroll row.
//

import SwiftUI

/// Square tile displaying a place with image or emoji placeholder.
struct CityPlaceTile: View {
    let place: CityTopPlace
    let onTap: () -> Void

    @ObservedObject private var externalMetadataCache = ExternalMetadataCache.shared

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                background

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(place.placeType.replacingOccurrences(of: "_", with: " ").capitalized)
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
        .onAppear { prefetchThumbnailIfNeeded() }
    }

    // MARK: - Photo Resolution

    /// Resolved photo URL using priority: review photo → external thumbnail → backend image_url.
    private var resolvedPhotoURL: URL? {
        if let reviewPhoto = place.latestReviewPhoto, let url = URL(string: reviewPhoto) {
            return url
        }
        if let contentUrl = place.contentUrl,
           let thumbStr = externalMetadataCache.getCachedThumbnailUrl(for: contentUrl),
           let url = URL(string: thumbStr) {
            return url
        }
        if let imageUrl = place.imageUrl, let url = URL(string: imageUrl) {
            return url
        }
        return nil
    }

    /// Prefetches external video thumbnail metadata if applicable.
    private func prefetchThumbnailIfNeeded() {
        guard let contentUrl = place.contentUrl else { return }
        Task { _ = await ExternalMetadataCache.shared.getMetadata(for: contentUrl) }
    }

    // MARK: - Background

    /// Image background with gradient or emoji placeholder.
    @ViewBuilder
    private var background: some View {
        if let url = resolvedPhotoURL {
            GeometryReader { geometry in
                CachedAsyncImage(url: url, targetSize: geometry.size) {
                    emojiPlaceholder
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(gradientOverlay)
            }
        } else {
            emojiPlaceholder
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

    /// Emoji placeholder for places without an image.
    private var emojiPlaceholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .overlay(
                Text(place.emoji)
                    .font(.system(size: 36))
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
