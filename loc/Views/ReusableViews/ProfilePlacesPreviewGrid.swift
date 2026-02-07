//
//  ProfilePlacesPreviewGrid.swift
//  loc
//
//  Shared 3x2 grid for profile preview sections (Favorites, TikToks, Reviews).
//  Displays up to 6 places with empty slot placeholders.
//
//  Single Responsibility: Render a 3-column grid of place cards with consistent styling.
//

import SwiftUI

/// Configuration for the profile places preview grid.
struct ProfilePlacesPreviewGridConfig {
    let preferTikTokThumbnail: Bool
    let maxItems: Int

    static let favorites = ProfilePlacesPreviewGridConfig(preferTikTokThumbnail: false, maxItems: 6)
    static let tiktoks = ProfilePlacesPreviewGridConfig(preferTikTokThumbnail: true, maxItems: 6)
    static let reviews = ProfilePlacesPreviewGridConfig(preferTikTokThumbnail: false, maxItems: 6)
    static let myPlaces = ProfilePlacesPreviewGridConfig(preferTikTokThumbnail: false, maxItems: 6)
}

/// Shared 3x2 grid for profile preview sections.
struct ProfilePlacesPreviewGrid<Item: Identifiable>: View {
    let items: [Item]
    let config: ProfilePlacesPreviewGridConfig
    let cardBuilder: (Item) -> ProfileGridPlaceCard

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(items.prefix(config.maxItems))) { item in
                cardBuilder(item)
            }

            // Fill remaining slots if less than maxItems
            if items.count < config.maxItems {
                ForEach(0..<(config.maxItems - min(items.count, config.maxItems)), id: \.self) { _ in
                    emptySlot
                }
            }
        }
    }

    private var emptySlot: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(height: 90)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Convenience Extensions

extension ProfilePlacesPreviewGrid where Item == FavoritePlace {
    /// Creates a grid for FavoritePlace items.
    init(favorites: [FavoritePlace]) {
        self.items = favorites
        self.config = .favorites
        self.cardBuilder = { ProfileGridPlaceCard(favoritePlace: $0) }
    }
}

extension ProfilePlacesPreviewGrid where Item == LightweightPlace {
    /// Creates a grid for LightweightPlace items with TikTok thumbnail priority.
    init(tiktokPlaces: [LightweightPlace]) {
        self.items = tiktokPlaces
        self.config = .tiktoks
        self.cardBuilder = { ProfileGridPlaceCard(place: $0, preferTikTokThumbnail: true) }
    }

    /// Creates a grid for LightweightPlace items with review photo priority.
    init(reviewedPlaces: [LightweightPlace]) {
        self.items = reviewedPlaces
        self.config = .reviews
        self.cardBuilder = { ProfileGridPlaceCard(place: $0, preferTikTokThumbnail: false) }
    }

    /// Creates a grid for LightweightPlace items showing user-created places.
    init(myPlaces: [LightweightPlace]) {
        self.items = myPlaces
        self.config = .myPlaces
        self.cardBuilder = { ProfileGridPlaceCard(place: $0, preferTikTokThumbnail: false) }
    }
}
