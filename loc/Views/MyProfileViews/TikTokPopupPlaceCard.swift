//
//  TikTokPopupPlaceCard.swift
//  loc
//
//  Single Responsibility: Display a TikTok place card with tap/long-press interactions
//  MVVM: All business logic delegated to ViewModels
//  Structure: Matches LightweightPlaceGridCell for consistent styling

import SwiftUI

struct TikTokPopupPlaceCard: View {
    let place: LightweightPlace
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showDeleteConfirmation = false
    
    // MARK: - Computed Properties
    
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    // MARK: - Body
    
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
                        .frame(height: 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        
                        // Place info overlay (top layer)
                        placeInfoOverlay
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            .onTapGesture {
                // Navigate via ViewModel (business logic in ViewModel)
                selectedPlaceVM.navigateToPlace(placeId: place.place_id) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onLongPressGesture { showDeleteConfirmation = true }
            .alert("Delete TikTok Place", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    profile.deleteTikTokPlace(place)
                }
            } message: {
                Text("Are you sure you want to delete \"\(place.name)\"? This action cannot be undone.")
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
}
