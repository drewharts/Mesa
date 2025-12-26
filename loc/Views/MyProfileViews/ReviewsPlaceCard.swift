//
//  ReviewsPlaceCard.swift
//  loc
//
//  Single Responsibility: Display a small review place card for profile preview grid
//  Matches TikTokPlaceCard structure for consistency

import SwiftUI

struct ReviewsPlaceCard: View {
    let place: LightweightPlace
    
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            thumbnailImage
            gradientOverlay
            placeNameOverlay
        }
        .frame(height: 90)
        .clipped()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }
    
    private var thumbnailImage: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 90)
            .overlay(
                Group {
                    if let photoURL = photoURL {
                        AsyncImage(url: photoURL) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 90)
                                .clipped()
                        } placeholder: {
                            coloredPlaceholder
                        }
                    } else if let thumbnailURL = thumbnailURL {
                        AsyncImage(url: thumbnailURL) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 90)
                                .clipped()
                        } placeholder: {
                            coloredPlaceholder
                        }
                    } else {
                        coloredPlaceholder
                    }
                }
                .clipped()
            )
    }
    
    private var coloredPlaceholder: some View {
        Rectangle()
            .foregroundColor(placeColor)
            .frame(maxWidth: .infinity, maxHeight: 90)
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.1), .black.opacity(0.2), .black.opacity(1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 90)
    }
    
    private var placeNameOverlay: some View {
        Text(place.name)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Computed URLs
    
    private var photoURL: URL? {
        guard let urlString = place.latest_review_photo else { return nil }
        return URL(string: urlString)
    }
    
    private var thumbnailURL: URL? {
        guard let tiktokUrl = place.tiktok_url,
              let urlString = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl)
        else { return nil }
        return URL(string: urlString)
    }
}

