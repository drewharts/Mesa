//
//  ModernPhotoGallery.swift
//  loc
//
//  Created by Mesa on 10/2/25.
//

import SwiftUI

struct ModernPhotoGallery: View {
    let items: [PhotoItem]
    let onImageTapped: (Int) -> Void
    var onVideoTapped: ((String) -> Void)? = nil
    var overflowCount: Int = 0

    @ObservedObject var photosViewModel: PlacePhotosViewModel

    // Configuration
    private let heroImageHeight: CGFloat = 200
    private let gridSpacing: CGFloat = 8
    private let cornerRadius: CGFloat = 12

    // Computed property to create staggered layout items
    private var staggeredLayoutItems: [StaggeredItem] {
        guard items.count > 1 else { return [] }

        var layoutItems: [StaggeredItem] = []
        let remainingPhotos = Array(items.dropFirst())
        var currentIndex = 0
        var rowIndex = 0

        while currentIndex < remainingPhotos.count {
            let isSinglePhotoRow = rowIndex % 2 == 1

            if isSinglePhotoRow {
                let actualIndex = currentIndex + 1
                if actualIndex < items.count {
                    layoutItems.append(.single(actualIndex))
                }
                currentIndex += 1
            } else {
                let indices = (0..<2).compactMap { photoIndex in
                    let actualIndex = currentIndex + photoIndex + 1
                    return actualIndex < items.count ? actualIndex : nil
                }
                if !indices.isEmpty {
                    layoutItems.append(.double(indices))
                }
                currentIndex += indices.count
            }
            rowIndex += 1
        }

        return layoutItems
    }

    // Enum to represent different layout items
    private enum StaggeredItem: Identifiable {
        case single(Int)
        case double([Int])

        var id: String {
            switch self {
            case .single(let index):
                return "single_\(index)"
            case .double(let indices):
                return "double_\(indices.map(String.init).joined(separator: "_"))"
            }
        }
    }

    // Helper to check if a photo should show the overflow indicator
    private func shouldShowOverflow(at index: Int) -> Bool {
        return index == items.count - 1 && overflowCount > 0
    }

    // Overlay view for "+X more" indicator
    @ViewBuilder
    private func overflowOverlay(at index: Int) -> some View {
        if shouldShowOverflow(at: index) {
            ZStack {
                Color.black.opacity(0.5)
                Text("+\(overflowCount)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Returns the index into photo-only items for the photo viewer.
    private func photoOnlyIndex(for galleryIndex: Int) -> Int {
        return items.prefix(galleryIndex + 1).filter { !$0.isVideo }.count - 1
    }

    /// Handles tap on a gallery item, routing to photo or video handler.
    private func handleItemTap(at index: Int) {
        let item = items[index]
        if item.isVideo, let videoUrl = item.videoUrl {
            onVideoTapped?(videoUrl)
        } else {
            onImageTapped(photoOnlyIndex(for: index))
        }
    }

    /// Play button overlay for video items.
    @ViewBuilder
    private func videoPlayOverlay(at index: Int) -> some View {
        if items[index].isVideo {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if items.isEmpty {
                emptyStateView
            } else {
                photoGalleryView
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No photos yet")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Photo Gallery View

    private var photoGalleryView: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: gridSpacing) {
                    heroImageView

                    ForEach(staggeredLayoutItems) { item in
                        staggeredItemView(item)
                    }

                    loadingIndicator

                    Color.clear.frame(height: 20)
                }
                .animation(.easeOut(duration: 0.3), value: items.count)
            }

            refreshIndicator
        }
    }

    // MARK: - Hero Image View

    @ViewBuilder
    private var heroImageView: some View {
        if let firstItem = items.first {
            GeometryReader { geo in
                AsyncPhotoItemView(
                    item: firstItem,
                    width: geo.size.width,
                    height: heroImageHeight,
                    cornerRadius: cornerRadius
                )
                .overlay(overflowOverlay(at: 0))
                .overlay(videoPlayOverlay(at: 0))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .frame(height: heroImageHeight)
            .onTapGesture {
                handleItemTap(at: 0)
            }
            .transition(.opacity.combined(with: .scale))
        }
    }

    // MARK: - Staggered Item View

    @ViewBuilder
    private func staggeredItemView(_ item: StaggeredItem) -> some View {
        switch item {
        case .single(let actualIndex):
            singlePhotoRow(at: actualIndex)

        case .double(let indices):
            doublePhotoRow(indices: indices)
        }
    }

    // MARK: - Single Photo Row

    private func singlePhotoRow(at actualIndex: Int) -> some View {
        GeometryReader { geo in
            AsyncPhotoItemView(
                item: items[actualIndex],
                width: geo.size.width,
                height: geo.size.width * 0.6,
                cornerRadius: cornerRadius
            )
            .overlay(overflowOverlay(at: actualIndex))
            .overlay(videoPlayOverlay(at: actualIndex))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .aspectRatio(5/3, contentMode: .fill)
        .onTapGesture {
            handleItemTap(at: actualIndex)
        }
        .onAppear {
            if actualIndex == items.count - 3 && !photosViewModel.allPhotosLoadedForCurrentPlace {
                photosViewModel.loadMorePhotos()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Double Photo Row

    private func doublePhotoRow(indices: [Int]) -> some View {
        HStack(spacing: gridSpacing) {
            ForEach(indices, id: \.self) { actualIndex in
                GeometryReader { geo in
                    AsyncPhotoItemView(
                        item: items[actualIndex],
                        width: geo.size.width,
                        height: geo.size.width * 0.8,
                        cornerRadius: cornerRadius
                    )
                    .overlay(overflowOverlay(at: actualIndex))
                    .overlay(videoPlayOverlay(at: actualIndex))
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
                .aspectRatio(5/4, contentMode: .fill)
                .onTapGesture {
                    handleItemTap(at: actualIndex)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    // MARK: - Loading Indicator

    @ViewBuilder
    private var loadingIndicator: some View {
        if photosViewModel.photoLoadingState == .loading && !items.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, 20)
                Spacer()
            }
        }
    }

    // MARK: - Refresh Indicator

    @ViewBuilder
    private var refreshIndicator: some View {
        if photosViewModel.isRefreshingImages {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Refreshing photos...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Preview
#Preview {
    let photosViewModel = PlacePhotosViewModel()

    let sampleItems = [
        PhotoItem(url: "https://example.com/1"),
        PhotoItem(url: "https://example.com/2"),
        PhotoItem(url: "https://example.com/3"),
        PhotoItem(url: "https://example.com/4"),
        PhotoItem(url: "https://example.com/5")
    ]

    return ModernPhotoGallery(
        items: sampleItems,
        onImageTapped: { index in
            print("Tapped image at index: \(index)")
        },
        photosViewModel: photosViewModel
    )
    .padding()
}
