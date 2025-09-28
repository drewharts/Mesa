//
//  VisiblePlacesPopupView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct VisiblePlacesPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var placeTypeFilterVM: PlaceTypeFilterViewModel
    
    @State private var placeColors: [UUID: Color] = [:]
    
    // Get all places currently visible on the map
    var visiblePlaces: [DetailPlace] {
        return placeTypeFilterVM.getFilteredPlaces()
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
                    Text("Visible Places")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Place count subtitle
                Text("\(visiblePlaces.count) place\(visiblePlaces.count == 1 ? "" : "s") on map")
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
                        
                        Text("No places visible")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Try adjusting your map filters or zoom level")
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
    
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Button(action: {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }) {
            ZStack(alignment: .bottom) {
                // Background image or color
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: cardWidth, height: cardHeight)
                    .overlay(
                        Group {
                            // Try to show place image first
                            if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .clipped()
                            } else {
                                // Fallback to colored background
                                Rectangle()
                                    .foregroundColor(placeColors[place.id] ?? .gray)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .onAppear {
                                        if detailPlaceViewModel.placeImages[place.id.uuidString] == nil {
                                            detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                                        }
                                    }
                            }
                        }
                        .clipped()
                    )
                
                // Gradient overlay for text readability
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: cardWidth, height: cardHeight)
                
                // Text overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let city = place.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(width: cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: cardWidth, height: cardHeight)
        .clipped()
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
