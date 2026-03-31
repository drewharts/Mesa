//
//  ExploreFeedTile.swift
//  loc
//
//  DUMB Component: Single tile in the Explore grid showing a video thumbnail
//  with place name overlay. Lazy-loads thumbnail via oEmbed cache.
//

import SwiftUI

struct ExploreFeedTile: View {
    let video: ExploreVideoItem
    let onTap: () -> Void

    @ObservedObject private var metadataCache = ExternalMetadataCache.shared

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                background
                placeOverlay
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .onAppear { prefetchThumbnail() }
    }

    // MARK: - Subviews

    private var placeOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(video.placeName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
            if !video.subtitle.isEmpty {
                Text(video.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(8)
    }

    // MARK: - Thumbnail Resolution

    /// Resolved thumbnail URL — prefers stored permanent URL, falls back to oEmbed cache.
    private var thumbnailURL: URL? {
        if let stored = video.thumbnailUrl, !stored.isEmpty, let url = URL(string: stored) {
            return url
        }
        guard let cached = metadataCache.getCachedThumbnailUrl(for: video.url),
              let url = URL(string: cached) else {
            return nil
        }
        return url
    }

    /// Triggers on-demand oEmbed fetch for this video's thumbnail.
    private var prefetchThumbnail: () -> Void {
        { Task { _ = await ExternalMetadataCache.shared.getMetadata(for: video.url) } }
    }

    // MARK: - Background

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

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.6)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var iconPlaceholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
            )
            .overlay(gradientOverlay)
    }
}
