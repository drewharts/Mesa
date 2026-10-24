//
//  ListCoverCollageCell.swift
//  loc
//
//  Single cell of a ListCoverCollage: fills and clips its image, and reports load failures
//  so the collage can swap in the next candidate image.
//

import SwiftUI

struct ListCoverCollageCell: View {
    let urlString: String

    var body: some View {
        ListCoverPlaceholder(seed: urlString, showsGlyph: false)
            .overlay(
                CachedAsyncImage(
                    url: URL(string: urlString),
                    targetSize: CGSize(width: 300, height: 300),
                    placeholder: { ShimmerView() },
                    onFailure: { ImageLoadFailureRegistry.shared.markFailed(urlString) }
                )
                .scaledToFill()
            )
            .clipped()
            .contentShape(Rectangle())
    }
}
