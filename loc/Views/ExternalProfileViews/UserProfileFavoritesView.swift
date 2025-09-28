//
//  UserProfileFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileFavoritesView: View {
    var userFavorites: [DetailPlace]
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var placeColors: [UUID: Color] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            favoritesHeader
            favoritesCard
            Divider()
                .padding(.horizontal, 20)
        }
    }
    
    private var favoritesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FAVORITES")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(userFavorites.count) place\(userFavorites.count == 1 ? "" : "s")")
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
                if userFavorites.isEmpty {
                    // Empty state
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
                } else {
                    // Favorites grid (2x3 layout like list previews)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(userFavorites.prefix(6)), id: \.id) { place in
                            ExternalFavoritePlaceCard(place: place)
                        }
                        
                        // Fill remaining slots if less than 6 favorites
                        if userFavorites.count < 6 {
                            ForEach(0..<(6 - userFavorites.count), id: \.self) { _ in
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
}

struct ExternalFavoritePlaceCard: View {
    let place: DetailPlace
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: 80)
                .overlay(
                    Group {
                        // Image loading matching new card styling
                        if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: place) {
                            AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: .infinity, height: 80)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: .infinity, height: 80)
                            }
                        } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: .infinity, height: 80)
                                .clipped()
                        } else {
                            Rectangle()
                                .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                .frame(width: .infinity, height: 80)
                                .onAppear {
                                    detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
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
                Text(place.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                
                if let city = place.city {
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
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            
            // Dismiss the user profile sheet properly
            userProfileViewModel.isUserDetailPresented = false
            
            // Also call presentationMode dismiss as backup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func getFirstTikTokThumbnail(for place: DetailPlace?) -> String? {
        guard let place = place else { return nil }
        
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        
        // For external users, we don't have access to their TikTok videos
        // This would need to be implemented if we want to show external user's TikTok videos
        return nil
    }
}
