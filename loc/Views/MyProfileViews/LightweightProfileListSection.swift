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
            // Photo collage - square aspect ratio
            Button(action: {
                showingListPopup = true
            }) {
                GeometryReader { geometry in
                    if !places.isEmpty {
                        // Photo collage fills the square card
                        ListPhotoCollage(
                            places: Array(places.prefix(3)),
                            placeColors: $placeColors,
                            totalHeight: geometry.size.width
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                    } else {
                        // Empty state
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No places yet")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(PlainButtonStyle())
            
            // List info below the photo
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

/// Photo collage component showing up to 3 photos edge-to-edge
/// - 1 photo: Full width/height
/// - 2 photos: Two equal columns
/// - 3 photos: 2 stacked on left, 1 tall on right
struct ListPhotoCollage: View {
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    var totalHeight: CGFloat = 150
    
    private var halfHeight: CGFloat { totalHeight / 2 }
    
    var body: some View {
        Group {
            switch places.count {
            case 0:
                // Empty state placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: totalHeight)
                
            case 1:
                // Single photo fills entire space
                CollagePhotoView(place: places[0], placeColors: $placeColors, height: totalHeight)
                
            case 2:
                // Two photos side by side
                HStack(spacing: 0) {
                    CollagePhotoView(place: places[0], placeColors: $placeColors, height: totalHeight)
                    CollagePhotoView(place: places[1], placeColors: $placeColors, height: totalHeight)
                }
                
            default:
                // 3+ photos: 2 stacked left, 1 tall right
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        CollagePhotoView(place: places[0], placeColors: $placeColors, height: halfHeight)
                        CollagePhotoView(place: places[1], placeColors: $placeColors, height: halfHeight)
                    }
                    CollagePhotoView(place: places[2], placeColors: $placeColors, height: totalHeight)
                }
            }
        }
        .frame(height: totalHeight)
        .clipped()
        .cornerRadius(8)
    }
}

/// Individual photo view for the collage - displays photo edge-to-edge
struct CollagePhotoView: View {
    let place: LightweightPlace
    @Binding var placeColors: [UUID: Color]
    var height: CGFloat
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxWidth: .infinity)
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
                                Rectangle()
                                    .foregroundColor(placeColor)
                                    .frame(maxWidth: .infinity, maxHeight: height)
                            case .empty:
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
                                Rectangle()
                                    .foregroundColor(placeColor)
                                    .frame(maxWidth: .infinity, maxHeight: height)
                            case .empty:
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
            .clipped()
    }
}

