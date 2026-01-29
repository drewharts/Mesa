//
//  ProfileFavoriteListView.swift
//  loc
//
//  Displays a preview grid of the user's favorite places.
//  Uses the shared ProfileGridPlaceCard component.
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            favoritesHeader
            favoritesCard
            Divider()
                .padding(.horizontal, 20)
        }
        .onAppear {
            print("📱 [ProfileFavoriteListView] View appeared - lightweightFavorites count: \(profile.favoritesViewModel.lightweightFavorites.count)")
        }
    }

    private var favoritesHeader: some View {
        HStack {
            Text("FAVORITES")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var favoritesCard: some View {
        Button(action: {
            // Could open a favorites popup or navigate to favorites view
        }) {
            Group {
                if profile.favoritesViewModel.lightweightFavorites.isEmpty {
                    emptyState
                } else {
                    ProfilePlacesPreviewGrid(favorites: profile.favoritesViewModel.lightweightFavorites)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        ProfileEmptyState(
            icon: "heart",
            title: "No favorites yet",
            message: "Add places to your favorites to see them here"
        )
    }
}

// MARK: - Legacy Cards (kept for backward compatibility)

/// Lightweight card that displays FavoritePlace data without needing full Place object.
/// Note: Consider using ProfileGridPlaceCard(favoritePlace:) instead for new code.
struct LightweightFavoritePlaceCard: View {
    let favoritePlace: FavoritePlace
    let isPriorityTile: Bool
    @EnvironmentObject var places: DetailPlaceViewModel

    var body: some View {
        ProfileGridPlaceCard(favoritePlace: favoritePlace)
    }
}

/// Legacy card for DetailPlace-based favorites.
/// Note: This is kept for backward compatibility with existing code.
struct FavoritePlaceCard: View {
    let place: String
    let isPriorityTile: Bool
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    private var detailPlace: DetailPlace? {
        places.places[place]
    }

    private var placeColor: Color {
        let hash = place.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 90)
                .overlay(imageContent.clipped())

            gradientOverlay
            textOverlay
        }
        .frame(height: 90)
        .clipped()
        .cornerRadius(8)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            guard let place = detailPlace else { return }
            selectedPlaceVM.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: detailPlace) {
            asyncImage(url: URL(string: firstTikTokThumbnail))
        } else if let detailPlace = detailPlace,
                  let photoUrls = detailPlace.photoUrls,
                  !photoUrls.isEmpty,
                  let photoUrl = photoUrls.first,
                  let url = URL(string: photoUrl) {
            asyncImage(url: url)
        } else if let image = places.placeImages[place] {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 90)
                .clipped()
        } else {
            Rectangle()
                .foregroundColor(placeColor)
                .frame(maxWidth: .infinity, maxHeight: 90)
        }
    }

    @ViewBuilder
    private func asyncImage(url: URL?) -> some View {
        if let url = url {
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
        }
    }

    private var gradientOverlay: some View {
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
    }

    private var textOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(detailPlace?.name ?? " ")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .multilineTextAlignment(.leading)

            if let city = detailPlace?.city {
                Text(city)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Gets the first TikTok thumbnail URL for a place.
    private func getFirstTikTokThumbnail(for place: DetailPlace?) -> String? {
        guard let place = place else { return nil }

        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }

        return profile.getFirstTikTokThumbnailURL(for: place.id.uuidString)
    }
}
