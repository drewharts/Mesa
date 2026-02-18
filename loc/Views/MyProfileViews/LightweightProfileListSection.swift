//
//  LightweightProfileListSection.swift
//  loc
//
//  Staff Engineer Refactor: Removed GeometryReader anti-pattern that caused
//  lists to disappear/reappear during scrolling in LazyVGrid.
//
//  Key insight: Use aspectRatio(1, contentMode: .fit) for square sizing
//  instead of runtime geometry measurement.
//
//  Created by Claude on 1/20/25.
//

import SwiftUI

// MARK: - Main List Section Component
struct LightweightProfileListSection: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    let allLists: [LightweightPlaceList]
    let currentIndex: Int
    @Binding var placeColors: [UUID: Color]
    let onTap: () -> Void

    private var totalPlaceCount: Int {
        return list.place_count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Photo collage button
            Button(action: onTap) {
                ListCardImage(places: places, placeColors: $placeColors)
            }
            .buttonStyle(PlainButtonStyle())

            // List info
            ListCardInfo(
                list: list,
                totalPlaceCount: totalPlaceCount
            )
        }
    }
}

// MARK: - List Card Image
/// Square image card for list preview - NO GeometryReader needed!
/// Uses aspectRatio(1, ...) for stable sizing in LazyVGrid.
private struct ListCardImage: View {
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    
    var body: some View {
        Group {
            if !places.isEmpty {
                ListPhotoCollage(
                    places: Array(places.prefix(3)),
                    placeColors: $placeColors
                )
            } else {
                EmptyListCard()
            }
        }
        .aspectRatio(1, contentMode: .fit) // This makes it square - no measurement needed!
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Empty List Card
private struct EmptyListCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No places yet")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - List Card Info
private struct ListCardInfo: View {
    let list: LightweightPlaceList
    let totalPlaceCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(list.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            if list.isSharedWithMe, let ownerName = list.owner_name {
                SharedByIndicator(
                    ownerName: ownerName,
                    ownerPhotoUrl: list.owner_photo_url,
                    collaboratorPhotos: list.collaborator_photos
                )
            } else {
                SharedWithIndicator(
                    collaboratorPhotos: list.collaborator_photos,
                    collaboratorCount: list.collaborator_count ?? 0,
                    placeCount: totalPlaceCount
                )
            }
        }
    }
}

// MARK: - Photo Collage
/// Shows up to 3 photos in a collage layout.
/// Uses flexible layout - fills available space without explicit dimensions.
struct ListPhotoCollage: View {
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    
    var body: some View {
        Group {
            switch places.count {
            case 0:
                Color.gray.opacity(0.1)
                
            case 1:
                CollagePhotoView(place: places[0], placeColors: $placeColors)
                
            case 2:
                HStack(spacing: 0) {
                    CollagePhotoView(place: places[0], placeColors: $placeColors)
                    CollagePhotoView(place: places[1], placeColors: $placeColors)
                }
                
            default:
                // 3+ photos: 2 stacked left, 1 tall right
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        CollagePhotoView(place: places[0], placeColors: $placeColors)
                        CollagePhotoView(place: places[1], placeColors: $placeColors)
                    }
                    CollagePhotoView(place: places[2], placeColors: $placeColors)
                }
            }
        }
    }
}

// MARK: - Collage Photo View
/// Individual photo in the collage with reactive TikTok thumbnail loading
struct CollagePhotoView: View {
    let place: LightweightPlace
    @Binding var placeColors: [UUID: Color]
    @ObservedObject var tikTokCache = TikTokMetadataCache.shared
    
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        // Base color that fills available space
        Rectangle()
            .fill(placeColor)
            .overlay(photoOverlay)
            .clipped()
    }
    
    @ViewBuilder
    private var photoOverlay: some View {
        if let tiktokUrl = place.tiktok_url,
           let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
            AsyncImage(url: URL(string: thumbnailURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    EmptyView() // Falls back to placeColor
                case .empty:
                    Color.gray.opacity(0.3)
                        .onAppear {
                            // Only fetch if not already cached
                            if TikTokMetadataCache.shared.getCachedMetadata(for: tiktokUrl) == nil {
                                Task {
                                    _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                }
                            }
                        }
                @unknown default:
                    EmptyView()
                }
            }
        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    EmptyView() // Falls back to placeColor
                case .empty:
                    Color.gray.opacity(0.3)
                @unknown default:
                    EmptyView()
                }
            }
        } else if let tiktokUrl = place.tiktok_url {
            // No cached thumbnail yet - show placeholder while fetching
            Color.gray.opacity(0.3)
                .onAppear {
                    // Only fetch if not already cached
                    if TikTokMetadataCache.shared.getCachedMetadata(for: tiktokUrl) == nil {
                        Task {
                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                        }
                    }
                }
        }
    }
}

// MARK: - Lightweight Place Preview Card
/// Displays a place preview with photo and name overlay with reactive TikTok thumbnail loading
struct LightweightPlacePreviewCard: View {
    let place: LightweightPlace
    @Binding var placeColors: [UUID: Color]
    var height: CGFloat = 80
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var tikTokCache = TikTokMetadataCache.shared
    
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    private var cornerRadius: CGFloat {
        height < 80 ? 6 : 8
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background with photo
            Rectangle()
                .fill(placeColor)
                .frame(height: height)
                .overlay(photoContent)
                .clipped()
            
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
    }
    
    @ViewBuilder
    private var photoContent: some View {
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
                    EmptyView()
                case .empty:
                    Color.gray.opacity(0.3)
                        .onAppear {
                            // Only fetch if not already cached
                            if TikTokMetadataCache.shared.getCachedMetadata(for: tiktokUrl) == nil {
                                Task {
                                    _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                }
                            }
                        }
                @unknown default:
                    EmptyView()
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
                    EmptyView()
                case .empty:
                    Color.gray.opacity(0.3)
                @unknown default:
                    EmptyView()
                }
            }
        } else if let tiktokUrl = place.tiktok_url {
            // No cached thumbnail yet - show placeholder while fetching
            Color.gray.opacity(0.3)
                .onAppear {
                    // Only fetch if not already cached
                    if TikTokMetadataCache.shared.getCachedMetadata(for: tiktokUrl) == nil {
                        Task {
                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                        }
                    }
                }
        }
    }
}
