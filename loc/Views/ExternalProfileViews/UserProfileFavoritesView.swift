//
//  UserProfileFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileFavoritesView: View {
    var userFavorites: [FavoritePlace]
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode

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
                        ForEach(Array(userFavorites.prefix(6)), id: \.id) { favoritePlace in
                            ExternalFavoritePlaceCard(favoritePlace: favoritePlace)
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
    let favoritePlace: FavoritePlace
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = favoritePlace.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: 80)
                .overlay(
                    Group {
                        // Image loading matching lightweight card styling
                        if let photoUrl = favoritePlace.latest_review_photo, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
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
                        } else {
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(maxWidth: .infinity, maxHeight: 80)
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
                Text(favoritePlace.name)
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
        .frame(height: 80)
        .clipped()
        .cornerRadius(8)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                // Load full place details and navigate
                Task {
                    await loadPlaceAndNavigate()
            }
        }
        )
    }
    
    private func loadPlaceAndNavigate() async {
        do {
            // Fetch the full place details
            let place = try await PlaceService.shared.fetchPlace(withId: favoritePlace.place_id)
            
            // Use centralized navigation method from UserProfileViewModel
            await MainActor.run {
                userProfileViewModel.navigateToPlaceFromProfile(place, selectedPlaceVM: selectedPlaceVM)
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}
