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
    @EnvironmentObject var mapViewModel: MapViewModel
    
    @State private var placeColors: [String: Color] = [:]
    
    // Get all places currently visible on the map from viewport annotations
    var visiblePlaces: [PlaceAnnotation] {
        guard let mapRegion = mapRegion else {
            return mapViewModel.viewportAnnotations
        }
        
        // Filter annotations to only include those within the visible map bounds
        return mapViewModel.viewportAnnotations.filter { annotation in
            let placeLat = annotation.coordinate.latitude
            let placeLon = annotation.coordinate.longitude
            
            // Check if place is within the visible map region
            let latMin = mapRegion.center.latitude - mapRegion.span.latitudeDelta / 2
            let latMax = mapRegion.center.latitude + mapRegion.span.latitudeDelta / 2
            let lonMin = mapRegion.center.longitude - mapRegion.span.longitudeDelta / 2
            let lonMax = mapRegion.center.longitude + mapRegion.span.longitudeDelta / 2
            
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
                            ForEach(visiblePlaces, id: \.place_id) { annotation in
                                VisiblePlaceGridCell(
                                    annotation: annotation,
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
        for annotation in visiblePlaces {
            if placeColors[annotation.place_id] == nil {
                placeColors[annotation.place_id] = Color(
                    red: Double.random(in: 0.3...0.9),
                    green: Double.random(in: 0.3...0.9),
                    blue: Double.random(in: 0.3...0.9)
                )
            }
        }
    }
}

struct VisiblePlaceGridCell: View {
    let annotation: PlaceAnnotation
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var placeColors: [String: Color]
    
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        if let color = placeColors[annotation.place_id] {
            return color
        }
        let hash = annotation.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        Button(action: {
            // Fetch full place details and navigate
            Task {
                await loadPlaceAndNavigate()
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Try to show cached image, otherwise show color
                    if let image = detailPlaceViewModel.placeImages[annotation.place_id] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    } else {
                        // Show colored rectangle fallback
                        Rectangle()
                            .foregroundColor(placeColor)
                            .frame(width: cardWidth, height: cardHeight)
                            .onAppear {
                                detailPlaceViewModel.fetchPlaceImage(for: annotation.place_id)
                            }
                    }
                    
                    // Gradient overlay
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
                    
                    // Place name
                    VStack(alignment: .leading, spacing: 4) {
                        Text(annotation.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadPlaceAndNavigate() async {
        do {
            // Fetch the full place details
            let fullPlace = try await PlaceService.shared.fetchPlace(withId: annotation.place_id)
            
            // Navigate to the place detail view
            await MainActor.run {
                selectedPlaceVM.selectedPlace = fullPlace
                selectedPlaceVM.isDetailSheetPresented = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}
