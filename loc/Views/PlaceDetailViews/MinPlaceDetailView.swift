//
//  MinPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/9/25.
//

import SwiftUI
import UIKit

struct MinPlaceDetailView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @ObservedObject var viewModel: PlaceDetailViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var userSession: UserSession
    @Environment(\.isScrollingEnabled) var isScrollingEnabled // Access scroll state

    @Binding var showNoPhoneNumberAlert: Bool
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    @State private var selectedTab: DetailTab = .about
    
    private var defaultTab: DetailTab {
        return selectedPlaceVM.reviews.isEmpty ? .about : .reviews
    }
    
    private var tikTokVideos: [TikTokVideo] {
        let placeTikTokVideos = selectedPlaceVM.tiktokVideos // Use the cached TikToks from ViewModel
        let userTikTokVideos = profile.getTikTokVideos(for: selectedPlaceVM.selectedPlace?.id.uuidString ?? "")
        
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                // MARK: - Top Row: Title + Icons
                HStack(alignment: .center) {
                    Text(selectedPlaceVM.selectedPlace?.name ?? "Loading...")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding(.bottom, 3)
                
                // MARK: - Row: Type / Google Maps / Drive Time
                HStack(spacing: 10) {
                    if let place = selectedPlaceVM.selectedPlace,
                       let restaurantType = viewModel.getRestaurantType(for: place) {
                        Text(restaurantType)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        if let place = selectedPlaceVM.selectedPlace {
                            let name = place.name
                            // If we have an address, include it for more accurate search
                            if let address = place.address {
                                viewModel.openGoogleMapsWithPlace(query: "\(name), \(address)")
                            } else if let latitude = place.coordinate?.latitude,
                                      let longitude = place.coordinate?.longitude {
                                // If no address, use name with coordinates
                                viewModel.openGoogleMapsWithPlace(query: "\(name) @\(latitude),\(longitude)")
                            } else {
                                // Fallback to just using the name
                                viewModel.openGoogleMapsWithPlace(query: name)
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.subheadline)
                                .foregroundColor(Color.green.opacity(0.8))
                            
                            Text("Maps")
                                .font(.subheadline)
                                .foregroundColor(Color.green.opacity(0.8))
                        }
                    }
                    
                    TravelTimeSelector(viewModel: viewModel)
                }
                .padding(.bottom, 10)
                
                // MARK: - Row: REVIEWS / Rating / ABOUT / Avatars
                HStack(spacing: 12) {
                    Button(action: {
                        selectedTab = .reviews
                    }) {
                        Text("REVIEWS")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if selectedTab == .reviews {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    Button(action: {
                        selectedTab = .notes
                    }) {
                        Text("NOTES")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if selectedTab == .notes {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    if !selectedPlaceVM.reviews.isEmpty && selectedPlaceVM.placeRating > 0 {
                        Text(String(format: "%.1f", selectedPlaceVM.placeRating))
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        selectedTab = .about
                    }) {
                        Text("ABOUT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if selectedTab == .about {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    ProfileCirclesView(placeId: selectedPlaceVM.selectedPlace?.id.uuidString)
                }
                .padding(.bottom, 10)
                
                // MARK: - Tab-Specific Content
                switch selectedTab {
                case .about:
                    // External Rating (Google/Mapbox)
                    if let rating = selectedPlaceVM.selectedPlace?.rating, rating > 0 {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                                
                                Text(String(format: "%.1f", rating))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                
                                if let count = selectedPlaceVM.selectedPlace?.userRatingsTotal, count > 0 {
                                    Text("(\(count.formatted()) reviews)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Google logo
                            Image("GoogleLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 16)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    Text(selectedPlaceVM.selectedPlace?.description ?? "No description available")
                        .font(.footnote)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    // TikTok Videos Section
                    if !tikTokVideos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("TikTok Videos")
                                    .font(.headline)
                                    .fontWeight(.bold)

                                Spacer()

                                Text("\(tikTokVideos.count)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(tikTokVideos, id: \.videoID) { video in
                                        TikTokVideoView(
                                            tikTokVideo: video,
                                            onDelete: {
                                                Task {
                                                    await deleteTikTok(video: video)
                                                }
                                            },
                                            showDeleteOption: true
                                        )
                                        .id("tiktok_\(video.videoID)")
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }
                        .padding(.top, 15)
                    }
                    
                    // TikTok Place Flagging (only for TikTok places)
                    if profile.hasTikTokVideos(for: selectedPlaceVM.selectedPlace?.id.uuidString ?? "") {
                        if let place = selectedPlaceVM.selectedPlace {
                            TikTokPlaceFlaggingView(place: place)
                                .environmentObject(profile)
                                .padding(.top, 15)
                        }
                    }

                    MaxPlaceDetailView(
                        viewModel: viewModel,
                        onPhotoTapped: onPhotoTapped
                    )
                case .reviews:
                    PlaceReviewsView(onPhotoTapped: onPhotoTapped)
                        .environmentObject(userProfileViewModel)
                case .notes:
                    if let selectedPlace = selectedPlaceVM.selectedPlace {
                        PlaceNoteView(place: selectedPlace)
                            .environmentObject(profile)
                    }
                }
            }
            .padding(.horizontal, 30)
        }
        .scrollDisabled(!isScrollingEnabled) // Disable scrolling based on sheet height
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedTab = defaultTab

            // Load review photos for the about section when the detail view appears
            if let place = selectedPlaceVM.selectedPlace {
                selectedPlaceVM.loadReviewPhotosForAbout(for: place)
            }
        }
        .onReceive(notificationManager.$highlightedReviewId) { reviewId in
            if reviewId != nil {
                // Switch to reviews tab when there's a highlighted review
                selectedTab = .reviews
            }
        }
        .alert(isPresented: $showNoPhoneNumberAlert) {
            Alert(
                title: Text("Phone Number Not Available"),
                message: Text("No phone number is available for this place."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Max Favorites Reached", isPresented: $profile.showMaxFavoritesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You already have 6 favorites. Remove one before adding a new one.")
        }
    }
    
    // MARK: - Helper Functions
    
    private func deleteTikTok(video: TikTokVideo) async {
        guard let placeId = selectedPlaceVM.selectedPlace?.id.uuidString,
              let userId = userSession.currentUserId else {
            return
        }
        
        do {
            try await TikTokPlaceService.shared.deleteTikTokFromPlace(
                placeId: placeId,
                videoId: video.videoID,
                userId: userId
            )
            
            // Refresh the profile to update the UI
            await MainActor.run {
                profile.fetchUserExternalPlaces()
            }
        } catch {
            print("❌ Error deleting TikTok: \(error)")
        }
    }
}

// MARK: - Sub-Types
enum DetailTab {
    case about
    case reviews
    case notes
}