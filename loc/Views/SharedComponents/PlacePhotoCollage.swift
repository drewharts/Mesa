//
//  PlacePhotoCollage.swift
//  loc
//
//  DUMB Component: Fills its frame with place photos (single photo, or a 2x2 grid for four or more).
//

import SwiftUI

/// Place-photo cover. `photoURLs` are candidates, validated up front: a shimmer shows until the final layout
/// (2x2 grid or one photo) is decided, then the photos fade in already loaded. Dead links are replaced by the next candidate before reveal.
struct PlacePhotoCollage: View {
    let photoURLs: [String]
    let cellSize: CGSize
    /// When false, only one photo is drawn full-frame, however many candidates exist.
    let allowsGrid

    @StateObject private var viewModel: PlacePhotoCollageViewModel

    private let spacing: CGFloat = 1.5

    /// Creates the collage; its layout is decided once by the view model and never changes shape afterwards.
    init(photoURLs: [String], cellSize: CGSize, allowsGrid: Bool = true) {
        self.photoURLs = photoURLs
        self.cellSize = cellSize
        self.allowsGrid = allowsGrid
        _viewModel = StateObject(wrappedValue: PlacePhotoCollageViewModel(candidates: photoURLs, allowsGrid: allowsGrid, frame: cellSize))
    }

    var body: some View {
        ZStack {
            if let urls = viewModel.resolved {
                layout(urls).transition(.opacity)
            } else if !photoURLs.isEmpty {
                ShimmerView().transition(.opacity)
            }
        }
        .task(id: photoURLs) { await viewModel.update(candidates: photoURLs) }
    }

    @ViewBuilder
    private func layout(_ urls: [String]) -> some View {
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
            CachedAsyncImage(url: URL(string: url), targetSize: size, placeholder: { Color.clear })
                .aspectRatio(contentMode: .fill)
        }
        .clipped()
        .id(url)
    }

    private var quarterSize: CGSize {
        PlacePhotoCollageLayout.cellSize(forPhotoCount: PlacePhotoCollageLayout.gridCount, frame: cellSize)
    }
}
