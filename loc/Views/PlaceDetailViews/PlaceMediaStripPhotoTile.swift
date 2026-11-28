//
//  PlaceMediaStripPhotoTile.swift
//  loc
//
//  A single photo or gallery-video tile in the place detail media strip.
//

import SwiftUI

struct PlaceMediaStripPhotoTile: View {
    let item: PlaceMediaStripItem
    let size: CGSize
    let cornerRadius: CGFloat
    let onTap: () -> Void
    let onLoadFailed: () -> Void

    var body: some View {
        AsyncPhotoItemView(
            item: PhotoItem(url: item.thumbnailURL, source: item.source ?? .userPost),
            width: size.width,
            height: size.height,
            cornerRadius: cornerRadius,
            onLoadFailed: { _ in onLoadFailed() }
        )
        .overlay(playBadge)
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.isVideo ? "Play video" : "Open photo")
    }

    /// Play badge shown over video tiles.
    @ViewBuilder
    private var playBadge: some View {
        if item.isVideo {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 3)
                .allowsHitTesting(false)
        }
    }
}
