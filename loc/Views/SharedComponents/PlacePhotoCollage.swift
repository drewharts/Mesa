//
//  PlacePhotoCollage.swift
//  loc
//
//  DUMB Component: Fills its frame with place photos (single photo, or a 2x2 grid for four or more).
//

import SwiftUI

/// Fades place photos in over whatever is behind it; renders nothing visible until images arrive.
/// `photoURLs` are candidates: photos that fail to load are skipped in favor of the next candidate.
struct PlacePhotoCollage: View {
    let photoURLs: [String]
    let cellSize: CGSize

    @ObservedObject private var failures = ImageLoadFailureRegistry.shared

    private let spacing: CGFloat = 1.5
    private let fadeDuration = 0.25

    private var visibleURLs: [String] {
        PlacePhotoCollageLayout.visibleURLs(photoURLs, failed: failures.failedURLs)
    }

    var body: some View {
        let urls = visibleURLs
        if urls.count >= PlacePhotoCollageLayout.gridCount {
            grid(urls)
        } else if let first = urls.first {
            photo(first, size: cellSize)
        }
    }

    // MARK: - Subviews

    private func grid(_ urls: [String]) -> some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                photo(urls[0], size: quarterSize)
                photo(urls[1], size: quarterSize)
            }
            HStack(spacing: spacing) {
                photo(urls[2], size: quarterSize)
                photo(urls[3], size: quarterSize)
            }
        }
    }

    /// One cropped, fading photo cell.
    private func photo(_ url: String, size: CGSize) -> some View {
        Color.clear.overlay {
            CachedAsyncImage(url: URL(string: url), targetSize: size, placeholder: { Color.clear }, onFailure: { ImageLoadFailureRegistry.shared.markFailed(url) }, fadeInDuration: fadeDuration)
                .aspectRatio(contentMode: .fill)
        }
        .clipped()
    }

    private var quarterSize: CGSize {
        PlacePhotoCollageLayout.cellSize(forPhotoCount: PlacePhotoCollageLayout.gridCount, frame: cellSize)
    }
}
