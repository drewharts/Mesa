//
//  MyPlacesListView.swift
//  loc
//
//  Single Responsibility: Display paginated My Places (created places) in a popup grid
//  MVVM: Delegates data loading and state to ProfileViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI
import UIKit

struct MyPlacesListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    var body: some View {
        PlaceListPopupView(
            title: "My Places",
            count: profile.totalMyPlacesCount,
            isLoading: profile.isMyPlacesLoading,
            isLoadingMore: profile.isLoadingMoreMyPlaces,
            places: profile.lightweightMyPlaces,
            hasMore: profile.hasMoreMyPlaces,
            emptyIcon: "mappin.and.ellipse",
            emptyTitle: "No Places Created Yet",
            emptyMessage: "Press and hold on the map to create a place at any location",
            loadMore: { await profile.loadMoreMyPlaces() },
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: true,  // Prefer TikTok thumbnail for visual consistency
                    allowDelete: true,
                    deleteTitle: "Delete Place",
                    onDelete: { profile.deleteMyPlace(place) },
                    onNavigate: navigate
                )
            }
        )
        .onAppear {
            if profile.lightweightMyPlaces.isEmpty {
                Task { await profile.loadInitialMyPlaces() }
            }
        }
    }
}

// MARK: - Helper Structs (Used by other views)

// Helper struct for alert binding
struct AlertIdentifier: Identifiable {
    let id: String
}

// MARK: - Lightweight Place Grid Cell
/// Square grid cell for place display - uses aspectRatio for flexible sizing (like ProfileView lists)
/// Single Responsibility: Display place thumbnail with name overlay, handle tap/long-press
/// For collaborative lists, shows "Added by [name]" indicator
struct LightweightPlaceGridCell: View {
    let place: LightweightPlace
    var isCollaborativeList: Bool = false  // Only show "Added by" for collaborative lists
    var onLongPress: (() -> Void)? = nil
    /// Custom navigation callback - when provided, bypasses default navigation
    /// Use this for external profile views that need to dismiss the profile sheet first
    var onNavigate: ((String) -> Void)? = nil
    /// Navigation callback for NavigationStack - pushes place ID onto navigation path
    var onNavigateToPlace: ((String) -> Void)? = nil
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Generate a consistent color for this place based on its ID
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    /// Should show the "Added by" indicator?
    /// Only for collaborative lists AND when added_by info is available
    private var shouldShowAddedBy: Bool {
        isCollaborativeList && place.added_by_name != nil
    }
    
    var body: some View {
        // Base Rectangle provides consistent size - aspectRatio works on Rectangle's intrinsic size
        Rectangle()
            .fill(placeColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Photo content overlays the background (bottom layer)
                        photoContent(size: geometry.size)
                        
                        // Gradient overlay for text readability (middle layer)
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: shouldShowAddedBy ? 80 : 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        
                        // Place info overlay (top layer)
                        placeInfoOverlay
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            .onTapGesture {
                if let navigateToPlace = onNavigateToPlace {
                    // Use NavigationStack navigation (push onto path)
                    navigateToPlace(place.place_id)
                } else if let customNavigate = onNavigate {
                    // Use custom navigation (e.g., for external profile views)
                    customNavigate(place.place_id)
                } else {
                    // Default navigation - just dismiss popup and show place
                    Task {
                        await loadPlaceAndNavigate()
                    }
                }
            }
            .onLongPressGesture {
                onLongPress?()
            }
    }
    
    // MARK: - Place Info Overlay
    
    private var placeInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
            
            // Show "Added by" for collaborative lists
            if shouldShowAddedBy, let addedByName = place.added_by_name {
                AddedByIndicator(
                    name: addedByName,
                    photoUrl: place.added_by_photo_url
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Photo Content
    @ViewBuilder
    private func photoContent(size: CGSize) -> some View {
        if let tiktokUrl = place.tiktok_url,
           let thumbnailURL = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl) {
            tiktokThumbnailView(thumbnailURL: thumbnailURL, tiktokUrl: tiktokUrl, size: size)
        } else if let photoUrl = place.latest_review_photo, let url = URL(string: photoUrl) {
            reviewPhotoView(url: url, size: size)
        } else {
            placeholderView
        }
    }
    
    @ViewBuilder
    private func tiktokThumbnailView(thumbnailURL: String, tiktokUrl: String, size: CGSize) -> some View {
        AsyncImage(url: URL(string: thumbnailURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                Color.clear // Falls back to background placeColor
            case .empty:
                loadingPlaceholder
                    .frame(width: size.width, height: size.height)
                    .onAppear {
                        Task {
                            _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                        }
                    }
            @unknown default:
                Color.clear
            }
        }
    }
    
    @ViewBuilder
    private func reviewPhotoView(url: URL, size: CGSize) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                Color.clear // Falls back to background placeColor
            case .empty:
                loadingPlaceholder
                    .frame(width: size.width, height: size.height)
            @unknown default:
                Color.clear
            }
        }
    }
    
    private var placeholderView: some View {
        Color.clear
            .onAppear {
                // Prefetch TikTok metadata if URL exists but no cached thumbnail
                if let tiktokUrl = place.tiktok_url {
                    Task {
                        _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl)
                    }
                }
            }
    }
    
    private var loadingPlaceholder: some View {
        Color.gray.opacity(0.3)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            )
    }
    
    private func loadPlaceAndNavigate() async {
        do {
            // Fetch the full place details using PlaceService
            let fullPlace = try await PlaceService.shared.fetchPlace(withId: place.place_id)
            
            // Navigate to the place detail view
            await MainActor.run {
                // Animate map to place location and fetch fresh details from backend
                selectedPlaceVM.selectPlaceAndFetchDetails(fullPlace, shouldAnimateMap: true)
                selectedPlaceVM.isDetailSheetPresented = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            print("❌ Error loading place details: \(error)")
        }
    }
}

// MARK: - Shared Place Grid Cell
struct PlaceGridCell: View {
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let colorForPlace: (DetailPlace) -> Color
    let isPriorityTile: Bool // New parameter to indicate if this is in the first 8 tiles
    var onLongPress: (() -> Void)? = nil
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                if let image = profile.detailPlaceViewModel.placeImages[place.id.uuidString], 
                   image.size.width > 0 && image.size.height > 0 {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    ZStack {
                        Rectangle()
                            .foregroundColor(colorForPlace(place))
                            .frame(width: cardWidth, height: cardHeight)
                        
                        // Show loading indicator if this is a priority tile and still loading
                        if isPriorityTile && profile.detailPlaceViewModel.isPlaceImageLoading(placeId: place.id.uuidString) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                    }
                    .onAppear {
                        // Load images for priority tiles immediately, or lazy load for others
                        profile.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                    }
                }
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                
                // Place name and city
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
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
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        .onTapGesture {
            selectedPlaceVM.selectPlaceAndFetchDetails(place)
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }
        .onLongPressGesture {
            onLongPress?()
        }
    }
}

// MARK: - Post Card
struct PostCard: View {
    let post: PlacePost
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with place name and date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.placeName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Text(formatDate(post.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Sentiment badge if provided
                if let wouldReturn = post.wouldReturn {
                    HStack(spacing: 4) {
                        Image(systemName: wouldReturn ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.caption2)
                        Text(wouldReturn ? "Would go back" : "Wouldn't revisit")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(wouldReturn ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(wouldReturn ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Post text
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
                    .foregroundColor(.black)
                    .lineLimit(3)
            }
            
            // Images if available
            if !post.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.images.prefix(3), id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            // Navigate to place detail
            if let place = profile.detailPlaceViewModel.places[post.placeId] {
                selectedPlaceVM.selectPlaceAndFetchDetails(place)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Post Rating View (kept for backwards compatibility)
struct ReviewRatingView: View {
    let title: String
    let rating: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
        }
    }
}
