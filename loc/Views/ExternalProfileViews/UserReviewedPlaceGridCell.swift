//
//  UserReviewedPlaceGridCell.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserReviewedPlaceGridCell: View {
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode

    private func getFirstTikTokThumbnail(for place: DetailPlace) -> String? {
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        
        // Check external places (user's TikTok videos for this place)
        return userProfileViewModel.getFirstTikTokThumbnailURL(for: place.id.uuidString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                if let thumbnailURL = getFirstTikTokThumbnail(for: place) {
                    // Show TikTok thumbnail
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .frame(width: cardWidth, height: cardHeight)
                    }
                } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                    // Show place review image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    // Show colored rectangle fallback
                    Rectangle()
                        .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                        .frame(width: cardWidth, height: cardHeight)
                }
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
                .frame(width: cardWidth, height: cardHeight)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name.isEmpty ? "Loading..." : place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    if let city = place.city, !city.isEmpty {
                        Text(city)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    } else if place.name.isEmpty {
                        Text("Loading details...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 20).inset(by: 50))
        .onTapGesture {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            
            // Dismiss the user profile sheet properly
            userProfileViewModel.isUserDetailPresented = false
            
            // Also call presentationMode dismiss as backup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
} 