//
//  CityTikTokTile.swift
//  loc
//
//  Tile view for a TikTok video in the city detail horizontal scroll row.
//

import SwiftUI

/// Square tile displaying a TikTok video thumbnail with place name overlay.
struct CityTikTokTile: View {
    let tiktok: CityTikTok
    let onTap: () -> Void

    @ObservedObject private var externalMetadataCache = ExternalMetadataCache.shared

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                background

                VStack(alignment: .leading, spacing: 2) {
                    Text(tiktok.placeName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(10)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .onAppear { prefetchThumbnail() }
    }

    // MARK: - Thumbnail Resolution

    /// Resolved thumbnail URL from the external metadata cache.
    private var thumbnailURL: URL? {
        guard let thumbStr = externalMetadataCache.getCachedThumbnailUrl(for: tiktok.url),
              let url = URL(string: thumbStr) else {
            return nil
        }
        return url
    }

    /// Triggers on-demand oEmbed fetch for this video's thumbnail.
    private func prefetchThumbnail() {
        Task { _ = await ExternalMetadataCache.shared.getMetadata(for: tiktok.url) }
    }

    // MARK: - Background

    /// Image background with gradient or icon placeholder.
    @ViewBuilder
    private var background: some View {
        if let url = thumbnailURL {
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

    /// Video icon placeholder shown while thumbnail loads.
    private var iconPlaceholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .overlay(
                Image(systemName: "play.rectangle.fill")
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
