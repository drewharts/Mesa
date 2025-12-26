//
//  ProfileFavoritesTikToksView.swift
//  loc
//

import SwiftUI

enum FavoritesTikToksTab: String, CaseIterable {
    case favorites = "FAVORITES"
    case tiktoks = "TIKTOKS"
    case reviews = "REVIEWS"
}

struct ProfileFavoritesTikToksView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    @State private var selectedTab: FavoritesTikToksTab = .favorites
    @State private var showingTikToksPopup = false
    @State private var showingReviewsPopup = false
    @State private var showingHelpSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tabHeader
            contentGrid
            Divider()
                .padding(.horizontal, 20)
        }
        .onAppear {
            // Load TikToks data if needed
            if profile.lightweightExternalPlaces.isEmpty && !profile.isLoadingTikTokPlaces {
                Task { await profile.loadInitialExternalPlaces() }
            }
            // Load reviewed places data if needed
            if profile.lightweightReviewedPlaces.isEmpty && !profile.isLoadingReviewedPlaces {
                Task {
                    await profile.loadMyReviewedPlacesWithPagination()
                }
            }
        }
        .sheet(isPresented: $showingTikToksPopup) {
            TikToksPopupView()
        }
        .sheet(isPresented: $showingReviewsPopup) {
            ReviewsListPopupView()
        }
        .sheet(isPresented: $showingHelpSheet) {
            TikTokImportHelpView()
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
            
            // TikToks tab
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .tiktoks 
                }
            }) {
                HStack(spacing: 4) {
                    Text("TikToks")
                        .font(.headline)
                        .fontWeight(selectedTab == .tiktoks ? .semibold : .regular)
                        .foregroundColor(selectedTab == .tiktoks ? .primary : .gray)
                    
                    // Help button only shown when TikToks tab is selected
                    if selectedTab == .tiktoks {
                        Button(action: { showingHelpSheet = true }) {
                            Image(systemName: "questionmark.circle")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
            case .tiktoks:
                tiktoksContent
            case .reviews:
                reviewsContent
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Favorites Content
    
    private var favoritesContent: some View {
        Group {
            if profile.lightweightFavorites.isEmpty {
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
            
            Text("Add places to your favorites to see them here")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var favoritesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(profile.lightweightFavorites.prefix(6).enumerated()), id: \.element.id) { index, favoritePlace in
                LightweightFavoritePlaceCard(favoritePlace: favoritePlace, isPriorityTile: index < 6)
            }
            
            // Fill remaining slots if less than 6 favorites
            if profile.lightweightFavorites.count < 6 {
                ForEach(0..<(6 - profile.lightweightFavorites.count), id: \.self) { _ in
                    emptySlot
                }
            }
        }
    }
    
    // MARK: - TikToks Content
    
    private var tiktoksContent: some View {
        Group {
            if profile.isLoadingTikTokPlaces {
                loadingTikToksState
            } else if profile.lightweightExternalPlaces.isEmpty {
                emptyTikToksState
            } else {
                tiktoksGrid
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingTikToksPopup = true
        }
    }
    
    private var loadingTikToksState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading TikToks...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyTikToksState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No TikToks yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Add places from TikTok videos to see them here")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var tiktoksGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(profile.lightweightExternalPlaces.prefix(6)) { place in
                TikTokPlaceCard(place: place)
            }
            
            // Fill remaining slots
            ForEach(0..<max(0, 6 - profile.lightweightExternalPlaces.count), id: \.self) { _ in
                emptySlot
            }
        }
    }
    
    // MARK: - Reviews Content
    
    private var reviewsContent: some View {
        Group {
            if profile.isLoadingReviewedPlaces {
                loadingReviewsState
            } else if profile.lightweightReviewedPlaces.isEmpty {
                emptyReviewsState
            } else {
                reviewsGrid
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingReviewsPopup = true
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
            
            Text("Places you've reviewed will appear here")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var reviewsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(profile.lightweightReviewedPlaces.prefix(6)) { place in
                ReviewsPlaceCard(place: place)
            }
            
            // Fill remaining slots
            ForEach(0..<max(0, 6 - profile.lightweightReviewedPlaces.count), id: \.self) { _ in
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

