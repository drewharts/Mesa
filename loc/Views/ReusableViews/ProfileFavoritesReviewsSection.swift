//
//  ProfileFavoritesReviewsSection.swift
//  loc
//
//  Unified tab section for profile Favorites/TikToks/Reviews.
//  Shared between MyProfile and ExternalProfile with configurable behavior.
//
//  Single Responsibility: Display tabbed content grids with proper loading and empty states.
//

import SwiftUI

/// Configuration for the profile favorites/reviews section.
struct ProfileFavoritesReviewsSectionConfig {
    let showTikToksTab: Bool       // true for MyProfile, false for External
    let ownerName: String?         // nil for MyProfile, user's name for External
    let isMyProfile: Bool          // Affects empty state messaging

    static let myProfile = ProfileFavoritesReviewsSectionConfig(
        showTikToksTab: true,
        ownerName: nil,
        isMyProfile: true
    )

    static func external(ownerName: String) -> ProfileFavoritesReviewsSectionConfig {
        ProfileFavoritesReviewsSectionConfig(
            showTikToksTab: false,
            ownerName: ownerName,
            isMyProfile: false
        )
    }
}

/// Data source for the profile favorites/reviews section.
struct ProfileFavoritesReviewsSectionData {
    let favorites: [FavoritePlace]
    let tiktokPlaces: [LightweightPlace]
    let reviewedPlaces: [LightweightPlace]
    let isLoadingTikToks: Bool
    let isLoadingReviews: Bool
}

/// Unified tab section for Favorites, TikToks, and Reviews.
struct ProfileFavoritesReviewsSection: View {
    let data: ProfileFavoritesReviewsSectionData
    let config: ProfileFavoritesReviewsSectionConfig

    // Callbacks
    let onFavoritesTap: () -> Void
    let onTikToksTap: (() -> Void)?
    let onReviewsTap: () -> Void
    let onTikTokHelpTap: (() -> Void)?

    @State private var selectedTabId: String = "favorites"

    // MARK: - Computed Properties

    private var tabs: [ProfileTab] {
        var result: [ProfileTab] = [.favorites]
        if config.showTikToksTab {
            result.append(.tiktoks)
        }
        result.append(.reviews)
        return result
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileTabHeader(
                tabs: tabs,
                selectedTabId: $selectedTabId,
                onHelpTap: config.showTikToksTab ? onTikTokHelpTap : nil
            )
            contentGrid
            Divider()
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Content Grid

    @ViewBuilder
    private var contentGrid: some View {
        Group {
            switch selectedTabId {
            case "favorites":
                favoritesContent
            case "tiktoks":
                tiktoksContent
            case "reviews":
                reviewsContent
            default:
                favoritesContent
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Favorites Content

    private var favoritesContent: some View {
        Group {
            if data.favorites.isEmpty {
                emptyFavoritesState
            } else {
                ProfilePlacesPreviewGrid(favorites: data.favorites)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFavoritesTap()
        }
    }

    private var emptyFavoritesState: some View {
        ProfileEmptyState(
            icon: "heart",
            title: "No favorites yet",
            message: config.isMyProfile
                ? "Add places to your favorites to see them here"
                : "This user hasn't added any favorites yet"
        )
    }

    // MARK: - TikToks Content

    @ViewBuilder
    private var tiktoksContent: some View {
        Group {
            if data.isLoadingTikToks {
                loadingState(text: "Loading TikToks...")
            } else if data.tiktokPlaces.isEmpty {
                emptyTikToksState
            } else {
                ProfilePlacesPreviewGrid(tiktokPlaces: data.tiktokPlaces)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTikToksTap?()
        }
    }

    private var emptyTikToksState: some View {
        ProfileEmptyState(
            icon: "video",
            title: "No TikToks yet",
            message: config.isMyProfile
                ? "Add places from TikTok videos to see them here"
                : "This user hasn't added any TikTok places yet"
        )
    }

    // MARK: - Reviews Content

    private var reviewsContent: some View {
        Group {
            if data.isLoadingReviews {
                loadingState(text: "Loading Reviews...")
            } else if data.reviewedPlaces.isEmpty {
                emptyReviewsState
            } else {
                ProfilePlacesPreviewGrid(reviewedPlaces: data.reviewedPlaces)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onReviewsTap()
        }
    }

    private var emptyReviewsState: some View {
        ProfileEmptyState(
            icon: "star.bubble",
            title: "No reviews yet",
            message: config.isMyProfile
                ? "Places you've reviewed will appear here"
                : "This user hasn't reviewed any places yet"
        )
    }

    // MARK: - Loading State

    private func loadingState(text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Empty State

/// Reusable empty state view for profile sections.
struct ProfileEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(message)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}
