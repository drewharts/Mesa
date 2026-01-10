//
//  CardBasedListPreview.swift
//  loc
//
//  Created by Andrew Hartsfield II on 9/22/25.
//

import SwiftUI

struct CardBasedListPreview: View {
    let list: PlaceList
    let placeIds: [String]?
    let detailPlaceViewModel: DetailPlaceViewModel
    @Binding var placeColors: [UUID: Color]
    let isLoading: Bool
    
    @State private var showingListPopup = false
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Get preview places (first 6 places for 2x3 grid)
    private var previewPlaces: [DetailPlace] {
        guard let placeIds = placeIds, !placeIds.isEmpty else { return [] }
        let previewPlaceIds = Array(placeIds.prefix(6))
        return previewPlaceIds.compactMap { placeIdString in
            guard let place = detailPlaceViewModel.places[placeIdString] else { return nil }
            return place
        }
    }
    
    // Get total place count for the list
    private var totalPlaceCount: Int {
        return placeIds?.count ?? 0
    }
    
    // Preload images for the first 6 priority tiles
    private func preloadPriorityImages() {
        // Use the optimized priority loading method
        profile.loadPriorityImagesForPlaces(previewPlaces, priorityCount: 6)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // List header with title and place count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(totalPlaceCount) place\(totalPlaceCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Card with places grid
            Button(action: {
                // Set list filter and navigate to map
                profile.selectedListIdForMap = list.id.uuidString
                // Dismiss profile view to show map
                presentationMode.wrappedValue.dismiss()
            }) {
                VStack(spacing: 0) {
                    if isLoading {
                        // Loading skeleton
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(0..<6, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 80)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(16)
                    } else if !previewPlaces.isEmpty {
                        // Places grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(Array(previewPlaces.enumerated()), id: \.element.id) { index, place in
                                PlacePreviewCard(
                                    place: place, 
                                    placeColors: $placeColors,
                                    isPriorityTile: index < 6 // First 6 tiles are priority (2x3 grid)
                                )
                            }
                            
                            // Fill remaining slots if less than 6 places
                            if previewPlaces.count < 6 {
                                ForEach(0..<(6 - previewPlaces.count), id: \.self) { _ in
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
                    } else {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No places yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("Add places to this list to see them here")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
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
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: showingListPopup)
        }
        .padding(.horizontal, 20)
        .onAppear {
            // Preload images for the first 6 priority tiles immediately
            preloadPriorityImages()
        }
    }
}

struct PlacePreviewCard: View {
    let place: DetailPlace
    @Binding var placeColors: [UUID: Color]
    let isPriorityTile: Bool // New parameter to indicate if this is in the first 8 tiles
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: 80)
                .overlay(
                    Group {
                        // Image loading matching popup view implementation
                        if let thumbnailURL = getFirstTikTokThumbnail(for: place) {
                            // Show TikTok thumbnail with proper phase handling
                            AsyncImage(url: URL(string: thumbnailURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                        .clipped()
                                case .failure:
                                    Rectangle()
                                        .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                case .empty:
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                }
                            }
                        } else if let photoUrls = place.photoUrls,
                                  !photoUrls.isEmpty,
                                  let photoUrl = photoUrls.first,
                                  let url = URL(string: photoUrl) {
                            // Show place's own photo (for created places) with proper phase handling
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                        .clipped()
                                case .failure:
                                    Rectangle()
                                        .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                case .empty:
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                        .frame(maxWidth: .infinity, maxHeight: 80)
                                }
                            }
                        } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString], 
                                  image.size.width > 0 && image.size.height > 0 {
                            // Show place review image (already loaded)
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 80)
                                .clipped()
                        } else {
                            // Show colored rectangle fallback
                            Rectangle()
                                .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
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
    }
    
    private func getFirstTikTokThumbnail(for place: DetailPlace) -> String? {
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first,
           !firstVideo.thumbnailURL.isEmpty {
            return firstVideo.thumbnailURL
        }
        
        // Check user's TikTok videos for this place (uses cached data)
        return profile.getFirstTikTokThumbnailURL(for: place.id.uuidString)
    }
    
    private func getFirstPhotoUrl(for place: DetailPlace) -> String? {
        if let photoUrls = place.photoUrls,
           let firstPhoto = photoUrls.first,
           !firstPhoto.isEmpty {
            return firstPhoto
        }
        return nil
    }
}

