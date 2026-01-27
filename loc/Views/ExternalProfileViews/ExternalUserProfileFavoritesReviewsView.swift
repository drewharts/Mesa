//
//  ExternalUserProfileFavoritesReviewsView.swift
//  loc
//
//  Favorites and Reviews tabs for external user profiles using ExternalUserProfileViewModel.
//

import SwiftUI

struct ExternalUserProfileFavoritesReviewsView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel

    @State private var selectedTab: UserFavoritesReviewsTab = .favorites
    @State private var hasSetInitialTab: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tabHeader
            contentGrid
            Divider()
                .padding(.horizontal, 20)
        }
        .onAppear {
            // Load reviewed places data if needed
            if viewModel.lightweightReviewedPlaces.isEmpty && !viewModel.isLoadingReviewedPlaces {
                Task {
                    await viewModel.loadUserReviewedPlacesWithPagination()
                }
            }

            // Set initial tab if favorites loading is already complete
            if !hasSetInitialTab && !viewModel.isLoadingFavorites {
                hasSetInitialTab = true
                if viewModel.userFavorites.isEmpty && !viewModel.lightweightReviewedPlaces.isEmpty {
                    selectedTab = .reviews
                }
            }
        }
        .onChange(of: viewModel.isLoadingFavorites) { _, isLoading in
            // When favorites finish loading, decide which tab to show
            if !isLoading && !hasSetInitialTab {
                hasSetInitialTab = true
                if viewModel.userFavorites.isEmpty && !viewModel.lightweightReviewedPlaces.isEmpty {
                    selectedTab = .reviews
                }
            }
        }
    }

    // MARK: - Tab Header

    private var tabHeader: some View {
        HStack(spacing: 16) {
            // Favorites tab
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .favorites
                }
            }) {
                Text("Favorites")
                    .font(.headline)
                    .fontWeight(selectedTab == .favorites ? .semibold : .regular)
                    .foregroundColor(selectedTab == .favorites ? .primary : .gray)
            }
            .buttonStyle(.plain)

            // Reviews tab
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .reviews
                }
            }) {
                Text("Reviews")
                    .font(.headline)
                    .fontWeight(selectedTab == .reviews ? .semibold : .regular)
                    .foregroundColor(selectedTab == .reviews ? .primary : .gray)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Content Grid

    private var contentGrid: some View {
        Group {
            switch selectedTab {
            case .favorites:
                favoritesContent
            case .reviews:
                reviewsContent
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Favorites Content

    private var favoritesContent: some View {
        Group {
            if viewModel.userFavorites.isEmpty {
                emptyFavoritesState
            } else {
                favoritesGrid
            }
        }
        .contentShape(Rectangle())
    }

    private var emptyFavoritesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text("No favorites yet")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("This user hasn't added any favorites yet")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private var favoritesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(viewModel.userFavorites.prefix(6)), id: \.id) { favoritePlace in
                ExternalFavoritePlaceCard(favoritePlace: favoritePlace)
            }

            // Fill remaining slots if less than 6 favorites
            if viewModel.userFavorites.count < 6 {
                ForEach(0..<(6 - viewModel.userFavorites.count), id: \.self) { _ in
                    emptySlot
                }
            }
        }
    }

    // MARK: - Reviews Content

    private var reviewsContent: some View {
        Group {
            if viewModel.isLoadingReviewedPlaces {
                loadingReviewsState
            } else if viewModel.lightweightReviewedPlaces.isEmpty {
                emptyReviewsState
            } else {
                reviewsGrid
            }
        }
        .contentShape(Rectangle())
    }

    private var loadingReviewsState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading Reviews...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private var emptyReviewsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.bubble")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text("No reviews yet")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("This user hasn't reviewed any places yet")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private var reviewsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(viewModel.lightweightReviewedPlaces.prefix(6)) { place in
                ExternalReviewPlaceCardView(place: place)
            }

            // Fill remaining slots
            ForEach(0..<max(0, 6 - viewModel.lightweightReviewedPlaces.count), id: \.self) { _ in
                emptySlot
            }
        }
    }

    // MARK: - Shared Components

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

// MARK: - External Review Place Card View

struct ExternalReviewPlaceCardView: View {
    let place: LightweightPlace

    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 90)
                .overlay(
                    Group {
                        if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: 90)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(maxWidth: .infinity, maxHeight: 90)
                            }
                        } else {
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(maxWidth: .infinity, maxHeight: 90)
                        }
                    }
                    .clipped()
                )

            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.2),
                    Color.black.opacity(1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 90)

            // Text overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 90)
        .clipped()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
