//
//  ExplorePhotoCollage.swift
//  loc
//
//  DUMB Component: Fills its frame with place photos (single photo, or a 2x2 grid for four or more).
//

import SwiftUI

/// Fades place photos in over whatever is behind it; renders nothing visible until images arrive.
struct ExplorePhotoCollage: View {
    let photoURLs: [String]
    let cellSize: CGSize

    private let spacing: CGFloat = 1.5
    private let fadeDuration = 0.25

    var body: some View {
        if photoURLs.count >= 4 {
            grid
        } else if let first = photoURLs.first {
            photo(first, size: cellSize)
        }
    }

    // MARK: - Subviews

    private var grid: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                photo(photoURLs[0], size: quarterSize)
                photo(photoURLs[1], size: quarterSize)
            }
            HStack(spacing: spacing) {
                photo(photoURLs[2], size: quarterSize)
                photo(photoURLs[3], size: quarterSize)
            }
        }
    }

    /// One cropped, fading photo cell.
    private func photo(_ url: String, size: CGSize) -> some View {
        Color.clear.overlay {
            CachedAsyncImage(url: URL(string: url), targetSize: size, placeholder: { Color.clear }, fadeInDuration: fadeDuration)
                .aspectRatio(contentMode: .fill)
        }
        .clipped()
    }

    private var quarterSize: CGSize {
        CGSize(width: cellSize.width / 2, height: cellSize.height / 2)
    }
}
