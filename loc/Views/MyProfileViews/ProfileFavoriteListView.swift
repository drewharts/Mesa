//
//  ProfileFavoriteListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode // For dismissing the sheet
    @State private var showSearch = false
    
    private func getFirstTikTokThumbnail(for place: DetailPlace?) -> String? {
        guard let place = place else { return nil }
        
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        
        // Check user's TikTok videos for this place
        let userTikTokVideos = profile.getTikTokVideos(for: place.id.uuidString)
        return userTikTokVideos.first?.thumbnailURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            favoritesHeader
            favoritesCard
            Divider()
                .padding(.horizontal, 20)
        }
        .onAppear {
            // Preload images for the first 6 priority tiles immediately
            preloadPriorityFavoriteImages()
        }
        // TODO: Add search functionality for adding more favorites
    }
    
    private var favoritesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FAVORITES")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(profile.userFavorites.count) place\(profile.userFavorites.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var favoritesCard: some View {
        Button(action: {
            // Could open a favorites popup or navigate to favorites view
        }) {
            VStack(spacing: 0) {
                if profile.userFavorites.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "heart")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No favorites yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Add places to your favorites to see them here")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                } else {
                    // Favorites grid (2x3 layout like list previews)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(profile.userFavorites.prefix(6).enumerated()), id: \.element) { index, place in
                            FavoritePlaceCard(place: place, isPriorityTile: index < 6)
                        }
                        
                        // Fill remaining slots if less than 6 favorites
                        if profile.userFavorites.count < 6 {
                            ForEach(0..<(6 - profile.userFavorites.count), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 80)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
    
    // Preload images for the first 6 priority favorite tiles
    private func preloadPriorityFavoriteImages() {
        let priorityFavorites = Array(profile.userFavorites.prefix(6))
        let favoritePlaces = priorityFavorites.compactMap { placeId in
            places.places[placeId]
        }
        // Use the optimized priority loading method
        profile.loadPriorityImagesForPlaces(favoritePlaces, priorityCount: 6)
    }
}

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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: 80)
                .overlay(
                    Group {
                        // Image loading matching new card styling
                        if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: detailPlace) {
                            AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                            }
                        } else if let image = places.placeImages[place] {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 80)
                                .clipped()
                        } else {
                            Rectangle()
                                .foregroundColor(places.colorForPlace(placeId: place))
                                .frame(maxWidth: .infinity, maxHeight: 80)
                                .onAppear {
                                    // Load images for priority tiles immediately, or lazy load for others
                                    if let detailPlace = detailPlace {
                                        profile.loadPlaceImageWithFallback(for: detailPlace)
                                    }
                                }
                        }
                    }
                    .clipped()
                )
            
            // Gradient overlay for text readability
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
            .frame(height: 80)
            
            // Text overlay
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
        .frame(height: 80)
        .clipped()
        .cornerRadius(8)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            selectedPlaceVM.selectedPlace = detailPlace
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func getFirstTikTokThumbnail(for place: DetailPlace?) -> String? {
        guard let place = place else { return nil }
        
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        
        // Check user's TikTok videos for this place
        let userTikTokVideos = profile.getTikTokVideos(for: place.id.uuidString)
        return userTikTokVideos.first?.thumbnailURL
    }
}

