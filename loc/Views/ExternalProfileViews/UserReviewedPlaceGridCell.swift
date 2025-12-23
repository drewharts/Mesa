//
//  UserReviewedPlaceGridCell.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

/// Grid cell for external user's reviewed places
/// Matches LightweightPlaceGridCell design - square tiles with bottom gradient overlay
struct UserReviewedPlaceGridCell: View {
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode

    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = place.id.uuidString.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    var body: some View {
        // Base Rectangle provides consistent size - aspectRatio works on Rectangle's intrinsic size
        Rectangle()
            .fill(placeColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Photo content overlays the background (bottom layer)
                        photoContent(size: geometry.size)
                        
                        // Gradient overlay for text readability (middle layer)
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        
                        // Place name overlay (top layer)
                        Text(place.name.isEmpty ? "Loading..." : place.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            .onTapGesture {
                userProfileViewModel.navigateToPlaceFromProfile(place, selectedPlaceVM: selectedPlaceVM)
            }
    }
    
    // MARK: - Photo Content
    
    @ViewBuilder
    private func photoContent(size: CGSize) -> some View {
        if let thumbnailURL = getFirstTikTokThumbnail() {
            tiktokThumbnailView(thumbnailURL: thumbnailURL, size: size)
        } else if let photoUrls = place.photoUrls,
                  !photoUrls.isEmpty,
                  let photoUrl = photoUrls.first,
                  let url = URL(string: photoUrl) {
            placePhotoView(url: url, size: size)
        } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
            cachedImageView(image: image, size: size)
        } else {
            placeholderView
        }
    }
    
    // MARK: - TikTok Thumbnail
    
    @ViewBuilder
    private func tiktokThumbnailView(thumbnailURL: String, size: CGSize) -> some View {
        AsyncImage(url: URL(string: thumbnailURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                Color.clear
            case .empty:
                loadingPlaceholder
                    .frame(width: size.width, height: size.height)
            @unknown default:
                Color.clear
            }
        }
    }
    
    // MARK: - Place Photo
    
    @ViewBuilder
    private func placePhotoView(url: URL, size: CGSize) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                Color.clear
            case .empty:
                loadingPlaceholder
                    .frame(width: size.width, height: size.height)
            @unknown default:
                Color.clear
            }
        }
    }
    
    // MARK: - Cached Image
    
    @ViewBuilder
    private func cachedImageView(image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
    
    // MARK: - Placeholder Views
    
    private var placeholderView: some View {
        Color.clear
    }
    
    private var loadingPlaceholder: some View {
        Color.gray.opacity(0.3)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            )
    }
    
    // MARK: - Helpers
    
    private func getFirstTikTokThumbnail() -> String? {
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        return nil
    }
}
