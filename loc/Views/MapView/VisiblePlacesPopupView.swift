//
//  VisiblePlacesPopupView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI
import MapKit

struct VisiblePlacesPopupView: View {
    let mapRegion: MKCoordinateRegion?
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var placeTypeFilterVM: PlaceTypeFilterViewModel
    
    @State private var placeColors: [UUID: Color] = [:]
    
    // Get all places currently visible on the map within the visible region
    var visiblePlaces: [DetailPlace] {
        let allFilteredPlaces = placeTypeFilterVM.getFilteredPlaces()
        
        guard let mapRegion = mapRegion else {
            return allFilteredPlaces
        }
        
        // Filter places to only include those within the visible map bounds
        return allFilteredPlaces.filter { place in
            guard let placeCoordinate = place.coordinate else { return false }
            
            let placeLat = placeCoordinate.latitude
            let placeLon = placeCoordinate.longitude
            
            // Check if place is within the visible map region
            let region = mapRegion
            let latMin = region.center.latitude - region.span.latitudeDelta / 2
            let latMax = region.center.latitude + region.span.latitudeDelta / 2
            let lonMin = region.center.longitude - region.span.longitudeDelta / 2
            let lonMax = region.center.longitude + region.span.longitudeDelta / 2
            
            return placeLat >= latMin && placeLat <= latMax && 
                   placeLon >= lonMin && placeLon <= lonMax
        }
    }
    
    // Card dimensions matching the list popup format
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Places in View")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Place count subtitle
                Text("\(visiblePlaces.count) place\(visiblePlaces.count == 1 ? "" : "s") in visible area")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                
                // Content
                if !visiblePlaces.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(visiblePlaces, id: \.id) { place in
                                VisiblePlaceGridCell(
                                    place: place,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight,
                                    placeColors: $placeColors
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                } else {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "map")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No places in view")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Try zooming out or panning to see more places")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Generate colors for all visible places
            generateColorsForPlaces()
        }
    }
    
    private func generateColorsForPlaces() {
        for place in visiblePlaces {
            if placeColors[place.id] == nil {
                placeColors[place.id] = Color(
                    red: Double.random(in: 0.3...0.9),
                    green: Double.random(in: 0.3...0.9),
                    blue: Double.random(in: 0.3...0.9)
                )
            }
        }
    }
}

struct VisiblePlaceGridCell: View {
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var placeColors: [UUID: Color]
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    private var tikTokVideos: [TikTokVideo] {
        let placeTikTokVideos = place.tikTokVideos ?? []
        let userTikTokVideos = profile.getTikTokVideos(for: place.id.uuidString)
        
        // Combine and deduplicate based on videoID or URL
        var allVideos = placeTikTokVideos
        
        for userVideo in userTikTokVideos {
            // Check if this video already exists (by videoID or URL)
            let alreadyExists = allVideos.contains { existingVideo in
                existingVideo.videoID == userVideo.videoID || existingVideo.url == userVideo.url
            }
            
            if !alreadyExists {
                allVideos.append(userVideo)
            }
        }
        
        return allVideos
    }
    
    private var firstTikTokThumbnail: String? {
        return tikTokVideos.first?.thumbnailURL
    }
    
    var body: some View {
        Button(action: {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    if let thumbnailURL = firstTikTokThumbnail {
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
                            .onAppear {
                                profile.loadPlaceImageWithFallback(for: place)
                            }
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
        .buttonStyle(PlainButtonStyle())
    }
}
