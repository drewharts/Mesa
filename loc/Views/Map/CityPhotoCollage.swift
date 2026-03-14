//
//  CityPhotoCollage.swift
//  loc
//
//  Staggered photo collage for the city detail sheet.
//  Shows a hero row + double row (3 photos max) matching the ModernPhotoGallery style.
//

import SwiftUI

/// Staggered photo collage showing up to 3 review photos with a "+N more" overflow badge.
struct CityPhotoCollage: View {
    let photos: [CityReviewPhoto]
    let totalCount: Int
    let onPhotoTap: (CityReviewPhoto) -> Void
    let onSeeAllTap: () -> Void

    private let maxPreviewCount = 3
    private let heroHeight: CGFloat = 200
    private let gridSpacing: CGFloat = 8
    private let cornerRadius: CGFloat = 12

    /// Number of additional photos beyond the visible preview.
    private var overflowCount: Int {
        max(0, totalCount - min(photos.count, maxPreviewCount))
    }

    var body: some View {
        VStack(spacing: gridSpacing) {
            heroRow
            doubleRow
        }
    }

    // MARK: - Hero Row

    /// Full-width hero image at the top of the collage.
    @ViewBuilder
    private var heroRow: some View {
        if let photo = photos.first {
            imageCell(photo: photo, index: 0)
                .frame(height: heroHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
    }

    // MARK: - Double Row

    /// Two photos side by side below the hero with 5:4 aspect ratio.
    @ViewBuilder
    private var doubleRow: some View {
        if photos.count >= 2 {
            HStack(spacing: gridSpacing) {
                imageCell(photo: photos[1], index: 1)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                if photos.count >= 3 {
                    imageCell(photo: photos[2], index: 2)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
            .aspectRatio(photos.count >= 3 ? 5/2 : 5/4, contentMode: .fill)
        }
    }

    // MARK: - Image Cell

    /// Single image cell with optional overflow badge.
    private func imageCell(photo: CityReviewPhoto, index: Int) -> some View {
        let isLastVisible = index == min(photos.count, maxPreviewCount) - 1
        let showOverflow = isLastVisible && overflowCount > 0

        return Button { showOverflow ? onSeeAllTap() : onPhotoTap(photo) } label: {
            ZStack {
                GeometryReader { geometry in
                    if let url = URL(string: photo.imageUrl) {
                        CachedAsyncImage(url: url, targetSize: geometry.size) {
                            placeholderView
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    } else {
                        placeholderView
                    }
                }

                if showOverflow {
                    overflowBadge
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overflow Badge

    /// "+N more" overlay shown on the last visible photo when more exist.
    private var overflowBadge: some View {
        ZStack {
            Color.black.opacity(0.5)

            Text("+\(overflowCount)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }

    /// Placeholder shown while photo loads or when URL is invalid.
    private var placeholderView: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .overlay(
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            )
    }
}
