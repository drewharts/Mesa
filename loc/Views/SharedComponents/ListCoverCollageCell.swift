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
        Color(.systemGray6)
            .overlay(
                CachedAsyncImage(
                    url: URL(string: urlString),
                    targetSize: CGSize(width: 300, height: 300),
                    placeholder: { Color(.systemGray6) },
                    onFailure: { ImageLoadFailureRegistry.shared.markFailed(urlString) }
                )
                .scaledToFill()
            )
            .clipped()
            .contentShape(Rectangle())
    }
}
