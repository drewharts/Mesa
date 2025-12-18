//
//  LightweightProfileListSection.swift
//  loc
//
//  Created by Claude on 1/20/25.
//

import SwiftUI

struct LightweightProfileListSection: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    let allLists: [LightweightPlaceList]
    let currentIndex: Int
    @Binding var placeColors: [UUID: Color]
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingListPopup = false
    
    // Get total place count from the list (from SQL function)
    private var totalPlaceCount: Int {
        return list.place_count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // List header with title and place count - compact version
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Show owner name if this is a shared list (collaborator view)
                    if list.isSharedWithMe, let ownerName = list.owner_name {
                        SharedByIndicator(
                            ownerName: ownerName,
                            ownerPhotoUrl: list.owner_photo_url,
                            collaboratorPhotos: list.collaborator_photos
                        )
                    } else {
                        // Owner view - show place count and collaborators if shared
                        SharedWithIndicator(
                            collaboratorPhotos: list.collaborator_photos,
                            collaboratorCount: list.collaborator_count ?? 0,
                            placeCount: totalPlaceCount
                        )
                    }
                }
                
                Spacer()
            }
            
            // Card with places grid - compact 2x2 layout
            Button(action: {
                showingListPopup = true
            }) {
                VStack(spacing: 0) {
                    if !places.isEmpty {
                        // Places grid (first 4 places in 2x2 layout for compact view)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                            ForEach(Array(places.prefix(4).enumerated()), id: \.element.id) { index, place in
                                LightweightPlacePreviewCard(
                                    place: place,
                                    placeColors: $placeColors,
                                    height: 60
                                )
                            }
                            
                            // Fill remaining slots if less than 4 places
                            if places.count < 4 {
                                ForEach(0..<(4 - places.count), id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 60)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(8)
                    } else {
                        // Empty state - compact
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No places yet")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingListPopup) {
            // Use lightweight popup with swiping support between all lists
            LightweightListPopupView(
                lists: allLists,
                initialListIndex: currentIndex,
                placeColors: $placeColors
            )
        }
    }
}

/// Lightweight place preview card - displays place without needing full DetailPlace object
struct LightweightPlacePreviewCard: View {
    let place: LightweightPlace
    @Binding var placeColors: [UUID: Color]
    var height: CGFloat = 80  // Default height, can be customized for compact layouts
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        // Use the place_id string to generate a consistent color
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    // Smaller corner radius for compact views
    private var cornerRadius: CGFloat {
        height < 80 ? 6 : 8
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: height)
                .overlay(
                    Group {
                        // Check for TikTok thumbnail first, then review photo, then colored rectangle
                        if let tiktokUrl = place.tiktok_url,
                           let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
                            AsyncImage(url: URL(string: thumbnailURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                        .clipped()
                                case .failure:
                                    // Fallback to colored rectangle on failure
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                case .empty:
                                    // Loading state
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                        .onAppear {
                                            Task {
                                                _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                            }
                                        }
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                }
                            }
                        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                        .clipped()
                                case .failure:
                                    // Fallback to colored rectangle on failure
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                case .empty:
                                    // Loading state
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(placeColor)
                                        .frame(maxWidth: .infinity, maxHeight: height)
                                }
                            }
                        } else {
                            Rectangle()
                                .foregroundColor(placeColor)
                                .frame(maxWidth: .infinity, maxHeight: height)
                                .onAppear {
                                    if let tiktokUrl = place.tiktok_url {
                                        Task {
                                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                        }
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
            .frame(height: height)
            
            // Text overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .clipped()
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        // Individual places are NOT tappable - only the whole list button is tappable
    }
}

