//
//  ProfileFavoritesReviewsSection.swift
//  loc
//
//  Unified tab section for profile Recently imported/Reviews/My Places (Favorites is hidden).
//  Shared between MyProfile and ExternalProfile with configurable behavior.
//
//  Single Responsibility: Display tabbed content grids with proper loading and empty states.
//

import SwiftUI

/// Configuration for the profile favorites/reviews section.
struct ProfileFavoritesReviewsSectionConfig {
    let showFavoritesTab: Bool     // false everywhere: favorites were removed from profiles (UI only)
    let showExternalPlacesTab: Bool       // true for MyProfile, false for External
    let showMyPlacesTab: Bool      // true for MyProfile, false for External
    let ownerName: String?         // nil for MyProfile, user's name for External
    let isMyProfile: Bool          // Affects empty state messaging

    static let myProfile = ProfileFavoritesReviewsSectionConfig(
        showFavoritesTab: false,
        showExternalPlacesTab: true,
        showMyPlacesTab: true,
        ownerName: nil,
        isMyProfile: true
    )

    static func external(ownerName: String) -> ProfileFavoritesReviewsSectionConfig {
        ProfileFavoritesReviewsSectionConfig(
            showFavoritesTab: false,
            showExternalPlacesTab: false,
            showMyPlacesTab: false,
            ownerName: ownerName,
            isMyProfile: false
        )
    }
}

/// Data source for the profile favorites/reviews section.
struct ProfileFavoritesReviewsSectionData {
    let favorites: [FavoritePlace]
    let externalPlaces: [LightweightPlace]
    let reviewedPlaces: [LightweightPlace]
    let myPlaces: [LightweightPlace]
    let isLoadingExternalPlaces: Bool
    let isLoadingReviews: Bool
    let isLoadingMyPlaces: Bool
    var isLoadingFavorites: Bool = false
}

/// Unified tab section for Recently imported (external places), Reviews, and My Places.
struct ProfileFavoritesReviewsSection: View {
    let data: ProfileFavoritesReviewsSectionData
    let config: ProfileFavoritesReviewsSectionConfig
    var initialTabId: String? = nil

    // Callbacks
    let onFavoritesTap: () -> Void
    let onExternalPlacesTap: (() -> Void)?
    let onReviewsTap: () -> Void
    let onMyPlacesTap: (() -> Void)?
    let onExternalPlacesHelpTap: (() -> Void)?

    /// Tab the user tapped; nil until they tap one, so the first tab is the default.
    @State private var pickedTabId: String? = nil

    // MARK: - Computed Properties

    private var tabs: [ProfileTab] {
        var result: [ProfileTab] = []
        if config.showExternalPlacesTab {
            result.append(.externalPlaces)
        }
        if config.showFavoritesTab {
            result.append(.favorites)
        }
        result.append(.reviews)
        if config.showMyPlacesTab {
            result.append(.myPlaces)
        }
        return result
    }

    /// The selected tab: the one the user tapped, else the caller's initial tab, else the first tab.
    private var selectedTabId: String {
        if let pickedTabId, tabs.contains(where: { $0.id == pickedTabId }) { return pickedTabId }
        if let initialTabId, tabs.contains(where: { $0.id == initialTabId }) { return initialTabId }
        return tabs.first?.id ?? ProfileTab.reviews.id
    }

    private var selectedTabBinding: Binding<String> {
        Binding(get: { selectedTabId }, set: { pickedTabId = $0 })
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileTabHeader(
                tabs: tabs,
                selectedTabId: selectedTabBinding,
                onHelpTap: config.showExternalPlacesTab ? onExternalPlacesHelpTap : nil
            )
            contentGrid
            Divider()
                .padding(.horizontal, 20)
        }
        .onChange(of: initialTabId) { _, _ in
            pickedTabId = nil
        }
    }

    // MARK: - Content Grid

    @ViewBuilder
    private var contentGrid: some View {
        ZStack(alignment: .top) {
            if config.showFavoritesTab {
                favoritesContent
                    .opacity(selectedTabId == "favorites" ? 1 : 0)
                    .allowsHitTesting(selectedTabId == "favorites")
                    .accessibilityHidden(selectedTabId != "favorites")
            }

            if config.showExternalPlacesTab {
                externalPlacesContent
                    .opacity(selectedTabId == "externalPlaces" ? 1 : 0)
                    .allowsHitTesting(selectedTabId == "externalPlaces")
                    .accessibilityHidden(selectedTabId != "externalPlaces")
            }

            reviewsContent
                .opacity(selectedTabId == "reviews" ? 1 : 0)
                .allowsHitTesting(selectedTabId == "reviews")
                .accessibilityHidden(selectedTabId != "reviews")

            if config.showMyPlacesTab {
                myPlacesContent
                    .opacity(selectedTabId == "myPlaces" ? 1 : 0)
                    .allowsHitTesting(selectedTabId == "myPlaces")
                    .accessibilityHidden(selectedTabId != "myPlaces")
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Favorites Content

    private var favoritesContent: some View {
        Group {
            if data.isLoadingFavorites && data.favorites.isEmpty {
                SkeletonProfilePreviewGrid()
                    .loadFadeIn()
            } else if data.favorites.isEmpty {
                emptyFavoritesState
                    .loadFadeIn()
            } else {
                ProfilePlacesPreviewGrid(favorites: data.favorites)
                    .loadFadeIn()
            }
        }
        .animation(.easeOut(duration: 0.22), value: data.isLoadingFavorites)
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

    // MARK: - External Places Content

    @ViewBuilder
    private var externalPlacesContent: some View {
        Group {
            if data.isLoadingExternalPlaces && data.externalPlaces.isEmpty {
                loadingState(text: "Loading recent imports...")
            } else if data.externalPlaces.isEmpty {
                emptyExternalPlacesState
            } else {
                ProfilePlacesPreviewGrid(externalPlaces: data.externalPlaces)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onExternalPlacesTap?()
        }
    }

    private var emptyExternalPlacesState: some View {
        ProfileEmptyState(
            icon: "video",
            title: "Nothing imported yet",
            message: config.isMyProfile
                ? "Add places from videos to see them here"
                : "This user hasn't imported any places yet"
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

    // MARK: - My Places Content

    /// Displays My Places grid with loading and empty states.
    @ViewBuilder
    private var myPlacesContent: some View {
        Group {
            if data.isLoadingMyPlaces {
                loadingState(text: "Loading My Places...")
            } else if data.myPlaces.isEmpty {
                emptyMyPlacesState
            } else {
                ProfilePlacesPreviewGrid(myPlaces: data.myPlaces)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onMyPlacesTap?()
        }
    }

    /// Empty state shown when the user has no created places.
    private var emptyMyPlacesState: some View {
        ProfileEmptyState(
            icon: "mappin.and.ellipse",
            title: "No places yet",
            message: "Press and hold on the map to create a place"
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
