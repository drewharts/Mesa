import SwiftUI

struct TikTokPlaceSelectionView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @State private var selectedPlaceForList: DetailPlace?
    @State private var showingListSelection = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // TikTok Thumbnail Header
                if let firstPlace = profile.importedPlaces.first,
                   let firstTikTokVideo = firstPlace.tikTokVideos?.first,
                   !firstTikTokVideo.thumbnailURL.isEmpty {
                    
                    VStack(spacing: 12) {
                        Text("Found Places in TikTok")
                            .font(.headline)
                            .padding(.top, 16)
                        
                        Text("Found \(profile.importedPlaces.count) place\(profile.importedPlaces.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        AsyncImage(url: URL(string: firstTikTokVideo.thumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        
                        if !firstTikTokVideo.author.displayName.isEmpty {
                            Text("@\(firstTikTokVideo.author.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                // Places List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(profile.importedPlaces, id: \.id) { place in
                            PlaceRowView(
                                place: place,
                                onBookmarkTapped: {
                                    selectedPlaceForList = place
                                    showingListSelection = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Bottom buttons
                VStack(spacing: 12) {
                    Divider()
                    
                    Button("Done") {
                        print("🔘 Done button tapped - clearing place selection")
                        profile.clearPlaceSelection()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("TikTok Places")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                // Ensure user's lists are loaded before showing list selection sheets
                profile.ensureListsLoaded()
                profile.placeSelectionViewAppeared()
            }
        }
        .sheet(isPresented: $showingListSelection) {
            if let place = selectedPlaceForList {
                ListSelectionSheet(
                    place: place,
                    isPresented: $showingListSelection
                )
                .environmentObject(profile)
                .environmentObject(detailPlaceViewModel)
                .onAppear {
                    print("🔍 [TikTokPlaceSelectionView] ListSelectionSheet appeared")
                    // Force ensure lists are loaded when sheet appears
                    profile.ensureListsLoaded()
                }
            }
        }
    }
}

struct PlaceRowView: View {
    let place: DetailPlace
    let onBookmarkTapped: () -> Void
    @EnvironmentObject var profile: ProfileViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Place Image
            AsyncImage(url: URL(string: place.photoUrls?.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Place Info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !(place.address?.isEmpty ?? true) {
                    Text(place.address!)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    if (place.rating ?? 0) > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", place.rating ?? 0))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let priceLevel = place.priceLevel, !priceLevel.isEmpty {
                        Text(priceLevel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Bookmark Button - shows filled if place is in any list
            Button(action: onBookmarkTapped) {
                Image(systemName: profile.isPlaceInAnyList(placeId: place.id.uuidString) ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(.trailing, 4)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
} 