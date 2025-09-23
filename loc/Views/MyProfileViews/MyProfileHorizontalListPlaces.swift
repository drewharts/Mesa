//
//  MyProfileHorizontalListPlaces.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct MyProfileHorizontalListPlaces: View {
    @EnvironmentObject var viewModel: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    let listId: UUID
    @Binding var placeColors: [UUID: Color]
    
    private func getFirstTikTokThumbnail(for place: DetailPlace) -> String? {
        // Check place's own TikTok videos first
        if let placeTikTokVideos = place.tikTokVideos,
           let firstVideo = placeTikTokVideos.first {
            return firstVideo.thumbnailURL
        }
        
        // Check user's TikTok videos for this place
        let userTikTokVideos = viewModel.getTikTokVideos(for: place.id.uuidString)
        return userTikTokVideos.first?.thumbnailURL
    }
    
    var places: [DetailPlace] {
        // Use paginated place IDs instead of all place IDs
        let placeIds = viewModel.getDisplayedPlaceIds(for: listId)
        let allPlaceIds = viewModel.userListsPlaces[listId.uuidString] ?? []
        print("🔍 [MyProfileHorizontalListPlaces] List \(listId): All place IDs: \(allPlaceIds.count), Displayed: \(placeIds.count)")
        
        return placeIds.compactMap { detailPlaceViewModel.places[$0] }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(places, id: \.id) { place in
                    Button(action: {
                        selectedPlaceVM.selectedPlace = place
                        selectedPlaceVM.isDetailSheetPresented = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        VStack(spacing: 4) {
                            // Check for TikTok thumbnail first, then review image, then colored rectangle
                            if let firstTikTokThumbnail = getFirstTikTokThumbnail(for: place) {
                                AsyncImage(url: URL(string: firstTikTokThumbnail)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 80)
                                        .cornerRadius(8)
                                        .clipped()
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                } placeholder: {
                                    Rectangle()
                                        .frame(width: 120, height: 80)
                                        .foregroundColor(.gray.opacity(0.3))
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                }
                            } else if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 80)
                                    .cornerRadius(8)
                                    .clipped()
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            } else {
                                Rectangle()
                                    .frame(width: 120, height: 80)
                                    .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                            
                            Text(place.name.prefix(20))
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 120)
                            
                            // Display restaurant type instead of city
                            if let type = detailPlaceViewModel.placeTypes[place.id.uuidString] {
                                Text(type.prefix(20))
                                    .foregroundColor(.black)
                                    .font(.caption)
                                    .fontWeight(.light)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 120)
                            } else if let city = place.city {
                                Text(city.prefix(20))
                                    .foregroundColor(.black)
                                    .font(.caption)
                                    .fontWeight(.light)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 120)
                            }
                        }
                        .padding(.trailing, 8)
                    }
                    .contextMenu {
                        Button {
                            ServiceContainer.shared.placeShareService.sharePlace(place)
                        } label: {
                            Label("Share place", systemImage: "square.and.arrow.up")
                        }
                    }
                    .onAppear {
                        // Load more places when we're near the end
                        if place == places.last && viewModel.hasMorePlaces(for: listId) && !viewModel.isLoadingMorePlaces(for: listId) {
                            print("🔍 [MyProfileHorizontalListPlaces] Loading more places for list \(listId)")
                            viewModel.loadNextPageForList(listId: listId)
                        }
                    }
                }
                
                // Show loading indicator if loading more places
                if viewModel.isLoadingMorePlaces(for: listId) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 120, height: 80)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            // Ensure pagination is initialized for this list
            let allPlaceIds = viewModel.userListsPlaces[listId.uuidString] ?? []
            if !allPlaceIds.isEmpty && viewModel.getDisplayedPlaceIds(for: listId).isEmpty {
                print("🔍 [MyProfileHorizontalListPlaces] Initializing pagination for list \(listId)")
                viewModel.initializeListPaginationIfNeeded(listId: listId)
            }
            
            for place in places {
                if placeColors[place.id] == nil {
                    placeColors[place.id] = Color(
                        red: Double.random(in: 0...1),
                        green: Double.random(in: 0...1),
                        blue: Double.random(in: 0...1)
                    )
                }
            }
        }
    }
}
