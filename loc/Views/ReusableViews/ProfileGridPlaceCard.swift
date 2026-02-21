//
//  ProfileGridPlaceCard.swift
//  loc
//
//  Unified 90px-height place card for all profile preview grids (Favorites, Videos, Reviews).
//  Replaces LightweightFavoritePlaceCard, ExternalPlaceCard, ReviewsPlaceCard, and ExternalReviewPlaceCardView.
//
//  Single Responsibility: Display a compact place card with photo, gradient overlay, and name.
//

import SwiftUI

/// Unified card component for profile grid displays.
/// Supports both FavoritePlace and LightweightPlace data models.
struct ProfileGridPlaceCard: View {
    let name: String
    let photoUrl: String?
    let placeId: String
    var contentUrl: String? = nil
    var preferExternalThumbnail: Bool = false
    var height: CGFloat = 90

    @ObservedObject private var externalMetadataCache = ExternalMetadataCache.shared

    // MARK: - Computed Properties

    private var placeColor: Color {
        let hash = placeId.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            thumbnailImage
            gradientOverlay
            placeNameOverlay
        }
        .frame(height: height)
        .clipped()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .allowsHitTesting(false)
        .onAppear { prefetchThumbnailIfNeeded() }
    }

    // MARK: - Thumbnail Image

    private var thumbnailImage: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: height)
            .overlay(
                Group {
                    if preferExternalThumbnail {
                        externalFirstImageContent
                    } else {
                        photoFirstImageContent
                    }
                }
                .clipped()
            )
    }

    /// Displays external video thumbnail first, falling back to review photo.
    @ViewBuilder
    private var externalFirstImageContent: some View {
        if let thumbnailURL = thumbnailURL {
            asyncImageView(url: thumbnailURL)
        } else if let photoURL = photoURL {
            asyncImageView(url: photoURL)
        } else {
            coloredPlaceholder
        }
    }

    /// Displays review photo first, falling back to external video thumbnail.
    @ViewBuilder
    private var photoFirstImageContent: some View {
        if let photoURL = photoURL {
            asyncImageView(url: photoURL)
        } else if let thumbnailURL = thumbnailURL {
            asyncImageView(url: thumbnailURL)
        } else {
            coloredPlaceholder
        }
    }

    /// Renders an AsyncImage with standard fill styling.
    @ViewBuilder
    private func asyncImageView(url: URL) -> some View {
        AsyncImage(url: url) { image in
            image.resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: height)
                .clipped()
        } placeholder: {
            coloredPlaceholder
        }
    }

    private var coloredPlaceholder: some View {
        ShimmerView()
            .frame(maxWidth: .infinity, maxHeight: height)
    }

    // MARK: - Gradient Overlay

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.1), .black.opacity(0.2), .black.opacity(1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
    }

    // MARK: - Place Name Overlay

    private var placeNameOverlay: some View {
        Text(name)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Computed URLs

    private var thumbnailURL: URL? {
        guard let contentUrl = contentUrl,
              let urlString = ExternalMetadataCache.shared.getCachedThumbnailUrl(for: contentUrl)
        else { return nil }
        return URL(string: urlString)
    }

    private var photoURL: URL? {
        guard let urlString = photoUrl else { return nil }
        return URL(string: urlString)
    }

    /// Prefetches external video thumbnail metadata if applicable.
    private func prefetchThumbnailIfNeeded() {
        guard let contentUrl = contentUrl else { return }
        Task { _ = await ExternalMetadataCache.shared.getMetadata(for: contentUrl) }
    }
}

// MARK: - Convenience Initializers

extension ProfileGridPlaceCard {
    /// Creates a card from a FavoritePlace model.
    init(favoritePlace: FavoritePlace) {
        self.name = favoritePlace.name
        self.photoUrl = favoritePlace.latest_review_photo
        self.placeId = favoritePlace.place_id
        self.contentUrl = nil
        self.preferExternalThumbnail = false
        self.height = 90
    }

    /// Creates a card from a LightweightPlace model.
    init(place: LightweightPlace, preferExternalThumbnail: Bool = false) {
        self.name = place.name
        self.photoUrl = place.latest_review_photo
        self.placeId = place.place_id
        self.contentUrl = place.content_url
        self.preferExternalThumbnail = preferExternalThumbnail
        self.height = 90
    }
}
