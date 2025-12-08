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
        VStack(alignment: .leading, spacing: 12) {
            // List header with title and place count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                    Text(list.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                        // Show collaboration badge if list has collaborators
                        if list.hasCollaborators {
                            CollaboratorBadge(collaboratorCount: list.collaborator_count ?? 0)
                        }
                    }
                    
                    // Show owner name if this is a shared list
                    if list.isSharedWithMe, let ownerName = list.owner_name {
                        SharedListIndicator(ownerName: ownerName)
                    } else {
                    Text("\(totalPlaceCount) place\(totalPlaceCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Card with places grid
            Button(action: {
                showingListPopup = true
            }) {
                VStack(spacing: 0) {
                    if !places.isEmpty {
                        // Places grid (first 6 places in 2x3 layout)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(Array(places.prefix(6).enumerated()), id: \.element.id) { index, place in
                                LightweightPlacePreviewCard(
                                    place: place,
                                    placeColors: $placeColors
                                )
                            }
                            
                            // Fill remaining slots if less than 6 places
                            if places.count < 6 {
                                ForEach(0..<(6 - places.count), id: \.self) { _ in
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
        }
        .padding(.horizontal, 20)
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
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        // Use the place_id string to generate a consistent color
        let hash = place.place_id.hashValue
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
                        // Check for TikTok thumbnail first, then review photo, then colored rectangle
                        if let tiktokUrl = place.tiktok_url,
                           let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
                            AsyncImage(url: URL(string: thumbnailURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(maxWidth: .infinity, maxHeight: 80)
                                    .onAppear {
                                        Task {
                                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                                        }
                                    }
                            }
                        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
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
            .frame(height: 80)
            
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
        .frame(height: 80)
        .clipped()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        // Individual places are NOT tappable - only the whole list button is tappable
    }
}

