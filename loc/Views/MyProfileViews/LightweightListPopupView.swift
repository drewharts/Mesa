//
//  LightweightListPopupView.swift
//  loc
//
//  Created by Claude on 1/20/25.
//

import SwiftUI

struct LightweightListPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    
    @State private var showOnlyUnvisited: Bool = false
    
    // Same layout as original popup
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Filtered places based on visited status
    var filteredPlaces: [LightweightPlace] {
        guard showOnlyUnvisited else { return places }
        
        // Filter out places that the current user has reviewed
        return places.filter { place in
            !profile.hasReviewedPlace(placeId: place.place_id)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with list name and controls
                VStack(spacing: 12) {
                    // Top bar with close button and share button
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Share button (if needed)
                        if let userId = profile.user?.id {
                            // TODO: Implement share functionality for lightweight lists
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // List name and place count
                    VStack(spacing: 4) {
                        Text(list.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text("\(list.place_count) place\(list.place_count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    
                    // Filter toggle
                    HStack {
                        Button(action: {
                            showOnlyUnvisited.toggle()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: showOnlyUnvisited ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(showOnlyUnvisited ? .blue : .gray)
                                
                                Text("Show only unvisited")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
                
                // Content
                if !filteredPlaces.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(filteredPlaces, id: \.id) { place in
                                LightweightPlaceGridCell(
                                    place: place,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                } else {
                    VStack(spacing: 8) {
                        Spacer()
                        if showOnlyUnvisited {
                            Text("No unvisited places in this list")
                                .foregroundColor(.gray)
                            Text("All places have been reviewed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No places in this list")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Ensure reviewed places are loaded for filtering
            profile.loadMyReviewedPlacesWithPagination()
        }
    }
}

/// Lightweight place grid cell - displays place without needing full DetailPlace object
struct LightweightPlaceGridCell: View {
    let place: LightweightPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                // Place image or colored background
                if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(placeColor)
                            .frame(width: cardWidth, height: cardHeight)
                    }
                } else {
                    Rectangle()
                        .foregroundColor(placeColor)
                        .frame(width: cardWidth, height: cardHeight)
                }
                
                // Gradient overlay for text readability (matching my places style)
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                
                // Place name and city (matching my places style)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    // Note: city not available in lightweight data, so we'll skip it
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            // When tapped, load the full place details and navigate
            Task {
                await loadPlaceAndNavigate()
            }
        }
    }
    
    private func loadPlaceAndNavigate() async {
        do {
            // Fetch the full place details using PlaceService
            let fullPlace = try await PlaceService.shared.fetchPlace(withId: place.place_id)
            
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

// Preview
struct LightweightListPopupView_Previews: PreviewProvider {
    static var previews: some View {
        LightweightListPopupView(
            list: LightweightPlaceList(
                list_id: "test-id",
                name: "Test List",
                is_public: true,
                image: nil,
                created_at: "2025-01-20",
                updated_at: "2025-01-20",
                distance_meters: 100.0,
                place_count: 5
            ),
            places: [
                LightweightPlace(
                    place_id: "place-1",
                    name: "Test Place 1",
                    latest_review_photo: nil
                ),
                LightweightPlace(
                    place_id: "place-2",
                    name: "Test Place 2",
                    latest_review_photo: nil
                )
            ],
            placeColors: .constant([:])
        )
    }
}
