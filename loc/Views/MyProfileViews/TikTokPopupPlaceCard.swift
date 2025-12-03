//
//  TikTokPopupPlaceCard.swift
//  loc
//
//  Single Responsibility: Display a TikTok place card with tap/long-press interactions
//  MVVM: All business logic delegated to ViewModels

import SwiftUI

struct TikTokPopupPlaceCard: View {
    let place: LightweightPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showDeleteConfirmation = false
    
    // MARK: - Computed Properties (allowed in Views per cursor rules)
    
    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    private var thumbnailURL: URL? {
        guard let tiktokUrl = place.tiktok_url,
              let urlString = TikTokMetadataCache.shared.getCachedThumbnailUrl(for: tiktokUrl)
        else { return nil }
        return URL(string: urlString)
    }
    
    private var photoURL: URL? {
        guard let urlString = place.latest_review_photo else { return nil }
        return URL(string: urlString)
    }
    
    // MARK: - Body
    
    var body: some View {
        cardContent
            .frame(width: cardWidth, height: cardHeight)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            .onTapGesture {
                // Navigate via ViewModel (business logic in ViewModel)
                selectedPlaceVM.navigateToPlace(placeId: place.place_id) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onLongPressGesture { showDeleteConfirmation = true }
            .onAppear {
                // Prefetch thumbnail via cache (fire-and-forget)
                if let tiktokUrl = place.tiktok_url {
                    Task { _ = await TikTokMetadataCache.shared.getMetadata(for: tiktokUrl) }
                }
            }
            .alert("Delete TikTok Place", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    // Delete via ViewModel (business logic in ViewModel)
                    profile.deleteTikTokPlace(place)
                }
            } message: {
                Text("Are you sure you want to delete \"\(place.name)\"? This action cannot be undone.")
            }
    }
    
    // MARK: - View Components (computed properties returning Views)
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                thumbnailImage
                gradientOverlay
                placeInfo
            }
        }
    }
    
    private var thumbnailImage: some View {
        Group {
            if let thumbnailURL = thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } placeholder: {
                    placeholderWithLoading
                }
            } else if let photoURL = photoURL {
                AsyncImage(url: photoURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } placeholder: {
                    placeholderSolid
                }
            } else {
                placeholderSolid
            }
        }
    }
    
    private var placeholderWithLoading: some View {
        Rectangle()
            .foregroundColor(placeColor)
            .frame(width: cardWidth, height: cardHeight)
            .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8))
    }
    
    private var placeholderSolid: some View {
        Rectangle()
            .foregroundColor(placeColor)
            .frame(width: cardWidth, height: cardHeight)
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 60)
    }
    
    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

