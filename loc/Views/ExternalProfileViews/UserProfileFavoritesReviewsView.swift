//
//  UserProfileFavoritesReviewsView.swift
//  loc
//
//  Created for design consistency between Profile View and External Profile View
//  Shows Favorites | Reviews tabs similar to ProfileFavoritesTikToksView
//

import SwiftUI

enum UserFavoritesReviewsTab: String, CaseIterable {
    case favorites = "FAVORITES"
    case reviews = "REVIEWS"
}

struct UserProfileFavoritesReviewsView: View {
    @ObservedObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    
    @State private var selectedTab: UserFavoritesReviewsTab = .favorites
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tabHeader
            contentGrid
            Divider()
                .padding(.horizontal, 20)
        }
        .onAppear {
            // Load reviewed places data if needed
            if userProfileVM.lightweightReviewedPlaces.isEmpty && !userProfileVM.isLoadingReviewedPlaces {
                Task {
                    await userProfileVM.loadUserReviewedPlacesWithPagination()
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
            if userProfileVM.userFavorites.isEmpty {
                emptyFavoritesState
            } else {
                favoritesGrid
            }
        }
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
            ForEach(Array(userProfileVM.userFavorites.prefix(6)), id: \.id) { favoritePlace in
                ExternalFavoritePlaceCard(favoritePlace: favoritePlace)
            }
            
            // Fill remaining slots if less than 6 favorites
            if userProfileVM.userFavorites.count < 6 {
                ForEach(0..<(6 - userProfileVM.userFavorites.count), id: \.self) { _ in
                    emptySlot
                }
            }
        }
    }
    
    // MARK: - Reviews Content
    
    private var reviewsContent: some View {
        Group {
            if userProfileVM.isLoadingReviewedPlaces {
                loadingReviewsState
            } else if userProfileVM.lightweightReviewedPlaces.isEmpty {
                emptyReviewsState
            } else {
                reviewsGrid
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss profile and show reviews on map (matches current user behavior)
            userProfileVM.triggerExternalReviewsOnMap()
        }
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
            ForEach(userProfileVM.lightweightReviewedPlaces.prefix(6)) { place in
                ExternalReviewPlaceCard(place: place)
            }
            
            // Fill remaining slots
            ForEach(0..<max(0, 6 - userProfileVM.lightweightReviewedPlaces.count), id: \.self) { _ in
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

// MARK: - External Review Place Card (for preview grid)

struct ExternalReviewPlaceCard: View {
    let place: LightweightPlace
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
                        // Prioritize review photo for reviews
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

