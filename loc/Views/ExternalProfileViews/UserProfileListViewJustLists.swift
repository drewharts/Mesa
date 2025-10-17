import SwiftUI

struct UserProfileListViewJustLists: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [PlaceList]
    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedList: PlaceList?
    @State private var showingPlacesPopup = false

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(placeLists) { list in
                ExternalProfileListSection(
                    list: list,
                    viewModel: viewModel,
                    placeColors: $placeColors,
                    selectedList: $selectedList,
                    showingPlacesPopup: $showingPlacesPopup
                )
            }
        }
        .sheet(isPresented: $showingPlacesPopup) {
            if let list = selectedList {
                UserProfileListPlacesPopupView(list: list, viewModel: viewModel, placeColors: $placeColors)
            }
        }
    }
}

struct ExternalProfileListSection: View {
    let list: PlaceList
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var placeColors: [UUID: Color]
    @Binding var selectedList: PlaceList?
    @Binding var showingPlacesPopup: Bool
    
    // Get preview places (first 6 places for 2x3 grid)
    private var previewPlaces: [DetailPlace] {
        guard let places = viewModel.placeListMapboxPlaces[list.id] else { return [] }
        return Array(places.prefix(6))
    }
    
    // Get total place count for the list
    private var totalPlaceCount: Int {
        return viewModel.placeListMapboxPlaces[list.id]?.count ?? 0
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
                selectedList = list
                showingPlacesPopup = true
            }) {
                VStack(spacing: 0) {
                    if !previewPlaces.isEmpty {
                        // Places grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(previewPlaces, id: \.id) { place in
                                ExternalPlacePreviewCard(place: place, placeColors: $placeColors)
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
                            
                            Text("This user hasn't added any places to this list yet")
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
            .animation(.easeInOut(duration: 0.1), value: showingPlacesPopup)
        }
        .padding(.horizontal, 20)
    }
}

struct ExternalPlacePreviewCard: View {
    let place: DetailPlace
    @Binding var placeColors: [UUID: Color]
    
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Container to strictly enforce bounds
            Rectangle()
                .fill(Color.clear)
                .frame(height: 80)
                .overlay(
                    Group {
                        // Image loading matching new card styling
                        if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: place) {
                            // Show TikTok thumbnail
                            AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: .infinity, height: 80)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: .infinity, height: 80)
                            }
                        } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                            // Show place review image
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: .infinity, height: 80)
                                .clipped()
                        } else {
                            // Show colored rectangle fallback
                            Rectangle()
                                .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                .frame(width: .infinity, height: 80)
                                .onAppear {
                                    detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
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
        .onTapGesture {
            selectedPlaceVM.selectPlaceAndFetchDetails(place)
            selectedPlaceVM.isDetailSheetPresented = true
            
            // Dismiss the user profile sheet properly
            userProfileViewModel.isUserDetailPresented = false
            
            // Also call presentationMode dismiss as backup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func getFirstTikTokThumbnail(for place: DetailPlace) -> String? {
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first,
           !firstVideo.thumbnailURL.isEmpty {
            return firstVideo.thumbnailURL
        }
        
        // For external users, we don't have access to their TikTok videos
        // This would need to be implemented if we want to show external user's TikTok videos
        return nil
    }
}