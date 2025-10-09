//
//  UserProfileListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileListPlacesPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    let list: PlaceList
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var placeColors: [UUID: Color]
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private func getFirstTikTokThumbnail(for place: DetailPlace) -> String? {
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        
        // Check external places (user's TikTok videos for this place)
        return viewModel.getFirstTikTokThumbnailURL(for: place.id.uuidString)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                
                Text(list.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
                .frame(height: 20)
            
            if let places = viewModel.placeListMapboxPlaces[list.id] {
                if !places.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(places, id: \.id) { place in
                                Button(action: {
                                    selectedPlaceVM.selectPlaceAndFetchDetails(place)
                                    selectedPlaceVM.isDetailSheetPresented = true
                                    
                                    // Dismiss the user profile sheet properly
                                    viewModel.isUserDetailPresented = false
                                    
                                    // Also call presentationMode dismiss as backup
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ZStack(alignment: .bottom) {
                                            // Check for TikTok thumbnails first
                                            if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: place) {
                                                AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
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
                                            } else if let image = viewModel.placeImages[place.id.uuidString] {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: cardWidth, height: cardHeight)
                                                    .clipped()
                                            } else {
                                                Rectangle()
                                                    .foregroundColor(placeColors[place.id] ?? .gray)
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
                                                Text(place.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .multilineTextAlignment(.leading)
                                                
                                                if let city = place.city {
                                                    Text(city)
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
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                } else {
                    Text("No places in this list")
                        .foregroundColor(.gray)
                        .padding(.vertical, 30)
                }
            } else {
                Text("Loading places...")
                    .foregroundColor(.gray)
                    .padding(.vertical, 30)
            }
        }
        .cornerRadius(20)
        .padding()
    }
}
